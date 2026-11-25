//! 在主线程解析 Godot 的 C ABI，工作线程通过静态方法同步借用只读 Variant。
//! 每次调用独占其输出，读锁让已进入的工作线程在场景卸载前完成。
use super::{GfSegmentVisibilityBackend, MAX_POINTS, MAX_SEGMENTS, Topology};
use godot::builtin::{PackedInt32Array, PackedInt64Array, StringName, Variant};
use godot::global::Error;
use godot::meta::GodotConvert;
use godot::prelude::*;
use godot::sys::{self, GodotFfi};
use std::ffi::c_void;
use std::ptr;
use std::sync::RwLock;

const INT: sys::GDExtensionVariantType = sys::GDEXTENSION_VARIANT_TYPE_INT;
const I32_ARRAY: sys::GDExtensionVariantType = sys::GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY;
const I64_ARRAY: sys::GDExtensionVariantType = sys::GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY;

type Internal = unsafe extern "C" fn(sys::GDExtensionVariantPtr) -> *mut c_void;
type Builtin = unsafe extern "C" fn(
    sys::GDExtensionTypePtr,
    *const sys::GDExtensionConstTypePtr,
    sys::GDExtensionTypePtr,
    i32,
);
type FromInt =
    unsafe extern "C" fn(sys::GDExtensionUninitializedVariantPtr, sys::GDExtensionTypePtr);

struct Abi {
    tag: sys::GDExtensionInterfaceVariantGetType,
    int: Internal,
    from_int: FromInt,
    i32_array: Internal,
    i64_array: Internal,
    size32: Builtin,
    size64: Builtin,
    resize64: Builtin,
    read32: sys::GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,
    read64: sys::GDExtensionInterfacePackedInt64ArrayOperatorIndexConst,
    write64: sys::GDExtensionInterfacePackedInt64ArrayOperatorIndex,
    construct: sys::GDExtensionInterfaceVariantConstruct,
    destroy: sys::GDExtensionInterfaceVariantDestroy,
}

// 在线程间共享的只有函数指针，场景卸载须取得写锁，因而会等待正在执行的调用。
static ABI: SceneBinding<Abi> = SceneBinding(RwLock::new(None));

struct SceneBinding<T>(RwLock<Option<T>>);

impl<T> SceneBinding<T> {
    fn replace(&self, binding: Option<T>) {
        *self.0.write().unwrap_or_else(|e| e.into_inner()) = binding;
    }

    /// 持有读锁直到回调返回。绑定已撤回或尚未发布时返回 `None`。
    fn call<R>(&self, operation: impl FnOnce(&T) -> R) -> Option<R> {
        let active = self.0.read().unwrap_or_else(|e| e.into_inner());
        active.as_ref().map(operation)
    }
}

/// 在场景初始化时注册静态方法。缺少所需的内建方法时保留脚本回退路径。
pub(crate) fn register() {
    // SAFETY: 此入口由主线程上的场景初始化回调调用，此时内部类已注册。
    let engine = unsafe { sys::on_main() };
    let size = StringName::from("size");
    let resize = StringName::from("resize");
    // SAFETY: 两个 StringName 在查询期间存活，方法签名哈希来自 Godot 对应的 size() 和 resize(int)。
    let resolve = || unsafe {
        Some(Abi {
            tag: engine.variant_get_type,
            int: (engine.variant_get_ptr_internal_getter)(INT)?,
            from_int: (engine.get_variant_from_type_constructor)(INT)?,
            i32_array: (engine.variant_get_ptr_internal_getter)(I32_ARRAY)?,
            i64_array: (engine.variant_get_ptr_internal_getter)(I64_ARRAY)?,
            size32: (engine.variant_get_ptr_builtin_method)(
                I32_ARRAY,
                size.sys().cast(),
                3173160232,
            )?,
            size64: (engine.variant_get_ptr_builtin_method)(
                I64_ARRAY,
                size.sys().cast(),
                3173160232,
            )?,
            resize64: (engine.variant_get_ptr_builtin_method)(
                I64_ARRAY,
                resize.sys().cast(),
                848867239,
            )?,
            read32: engine.packed_int32_array_operator_index_const,
            read64: engine.packed_int64_array_operator_index_const,
            write64: engine.packed_int64_array_operator_index,
            construct: engine.variant_construct,
            destroy: engine.variant_destroy,
        })
    };
    let Some(abi) = resolve() else { return };
    ABI.replace(Some(abi));

    let name = StringName::from("compute_pair_masks_v2");
    let properties = [
        PackedInt32Array::godot_shape().to_method_signature_property("xy"),
        PackedInt32Array::godot_shape().to_method_signature_property("segments"),
        PackedInt64Array::godot_shape().to_method_signature_property("blocked"),
        i64::godot_shape().to_method_signature_property("valid_mask"),
    ];
    let mut args = properties
        .each_ref()
        .map(|property| property.property_sys());
    let mut metadata = [sys::GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE; 4];
    let result = Variant::godot_shape().to_method_signature_property("");
    let info = sys::GDExtensionClassMethodInfo {
        name: name.sys().cast_mut().cast(),
        method_userdata: ptr::null_mut(),
        call_func: Some(call),
        ptrcall_func: None,
        method_flags: (sys::GDEXTENSION_METHOD_FLAG_STATIC | sys::GDEXTENSION_METHOD_FLAG_VARARG)
            as u32,
        has_return_value: 1,
        return_value_info: &mut result.property_sys(),
        return_value_metadata: sys::GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
        argument_count: args.len() as u32,
        arguments_info: args.as_mut_ptr(),
        arguments_metadata: metadata.as_mut_ptr(),
        default_argument_count: 0,
        default_arguments: ptr::null_mut(),
    };
    // SAFETY: ClassDB 在返回前复制方法描述，局部参数表此时有效。VARARG 只走已注册的 varcall。
    unsafe {
        (engine.classdb_register_extension_class_method)(
            sys::get_library(),
            GfSegmentVisibilityBackend::class_id().string_sys(),
            &info,
        );
    }
}

/// 等待所有已进入的调用离开后撤回 ABI，后续调用只能观察到未注册状态。
pub(crate) fn unregister() {
    ABI.replace(None);
}

/// Godot 的静态 varcall 入口，成功时返回掩码列，计算失败时返回整数错误码。
///
/// # Safety
///
/// Godot 必须提供本次调用有效的参数数组、已初始化且独立的结果 Variant 和可写错误槽。
/// 输入在回调返回前必须保持存活且只读。
unsafe extern "C" fn call(
    _: *mut c_void,
    _: sys::GDExtensionClassInstancePtr,
    args: *const sys::GDExtensionConstVariantPtr,
    argc: i64,
    result: sys::GDExtensionVariantPtr,
    error: *mut sys::GDExtensionCallError,
) {
    // SAFETY: 入口契约保证错误槽和参数有效，读锁使 ABI 在整个计算期间有效。
    let completed = ABI.call(|abi| unsafe {
        (*error).error = sys::GDEXTENSION_CALL_OK;
        // 可能发生 unwind 的 Rust 计算期间，结果槽必须始终持有可销毁的 Variant。
        let compute = || {
            if argc != 4 {
                return Err(Error::ERR_INVALID_PARAMETER);
            }
            let args = &*args.cast::<[sys::GDExtensionConstVariantPtr; 4]>();
            abi.compute(args, result)
        };
        if let Err(failure) = std::panic::catch_unwind(compute).unwrap_or(Err(Error::FAILED)) {
            (abi.destroy)(result);
            let mut code = i64::from(failure.ord());
            (abi.from_int)(result.cast(), (&raw mut code).cast());
        }
    });
    if completed.is_none() {
        // SAFETY: 即使绑定已经撤回，Godot 提供的错误槽仍在本次回调内有效。
        unsafe { (*error).error = sys::GDEXTENSION_CALL_ERROR_INVALID_METHOD };
    }
}

impl Abi {
    /// 校验参数和工作量，在独立的结果槽构造掩码列。
    ///
    /// # Safety
    ///
    /// 四个参数指针须指向计算期间存活、只读的 Variant，结果槽须已初始化且与输入不别名。
    unsafe fn compute(
        &self,
        args: &[sys::GDExtensionConstVariantPtr; 4],
        result: sys::GDExtensionVariantPtr,
    ) -> Result<(), Error> {
        // SAFETY: 先校验四个 Variant 的实际类型，再借用其连续存储。调用期间输入只读，长度受预算约束。
        unsafe {
            for (&arg, expected) in args.iter().zip([I32_ARRAY, I32_ARRAY, I64_ARRAY, INT]) {
                if (self.tag)(arg) != expected {
                    return Err(Error::ERR_INVALID_PARAMETER);
                }
            }
            let xy = (self.i32_array)(args[0].cast_mut()).cast();
            let segments = (self.i32_array)(args[1].cast_mut()).cast();
            let blocked = (self.i64_array)(args[2].cast_mut()).cast();
            let valid_mask = *(self.int)(args[3].cast_mut()).cast::<i64>();
            let input = Topology::admit(
                column(xy, self.size32, self.read32, MAX_POINTS * 2)?,
                column(segments, self.size32, self.read32, MAX_SEGMENTS * 6)?,
                column(blocked, self.size64, self.read64, MAX_SEGMENTS)?,
                valid_mask,
            )
            .ok_or(Error::ERR_INVALID_PARAMETER)?;

            // 结果槽与输入独立，整批数据通过检查后才构造输出数组。
            let mut error = sys::GDExtensionCallError {
                error: 0,
                argument: 0,
                expected: 0,
            };
            (self.destroy)(result);
            (self.construct)(I64_ARRAY, result.cast(), ptr::null(), 0, &mut error);
            if error.error != sys::GDEXTENSION_CALL_OK {
                return Err(Error::FAILED);
            }
            let count = input.pair_count as i64;
            if count > 0 {
                let output = (self.i64_array)(result).cast();
                let mut status = 0_i64;
                (self.resize64)(
                    output,
                    &(&raw const count).cast(),
                    (&raw mut status).cast(),
                    1,
                );
                if status != 0 {
                    return Err(Error::ERR_OUT_OF_MEMORY);
                }
                let first = (self.write64)(output, 0);
                if first.is_null() {
                    return Err(Error::ERR_OUT_OF_MEMORY);
                }
                input.fill(std::slice::from_raw_parts_mut(first, input.pair_count));
            }
            Ok(())
        }
    }
}

/// 借用最多 `limit` 个元素，空列直接返回空切片。
///
/// # Safety
///
/// `base`、`size` 和 `read` 必须来自同一数组类型，元素布局与 `T` 一致。调用者保证数组的
/// 连续存储在整个 `'a` 内存活且不可变，长度对应的字节数可由 `isize` 表示。
unsafe fn column<'a, T>(
    base: sys::GDExtensionTypePtr,
    size: Builtin,
    read: unsafe extern "C" fn(sys::GDExtensionConstTypePtr, i64) -> *const T,
    limit: usize,
) -> Result<&'a [T], Error> {
    let mut count = 0_i64;
    // SAFETY: size 对应 base 的类型，无参数，count 提供对齐的 i64 结果槽。
    unsafe { size(base, ptr::null(), (&raw mut count).cast(), 0) };
    let count = usize::try_from(count).map_err(|_| Error::ERR_INVALID_PARAMETER)?;
    if count > limit {
        return Err(Error::ERR_INVALID_PARAMETER);
    }
    if count == 0 {
        return Ok(&[]);
    }
    // SAFETY: 已验证数组非空，索引零有效，read 对应同一存储类型。
    let first = unsafe { read(base, 0) };
    if first.is_null() {
        return Err(Error::ERR_INVALID_PARAMETER);
    }
    // SAFETY: 首地址非空，数组长度已校验，类型对齐、连续性和 'a 的借用期限由入口契约保证。
    Ok(unsafe { std::slice::from_raw_parts(first, count) })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{TryLockError, mpsc};
    use std::time::Duration;

    #[test]
    fn cancelling_the_owner_and_closing_the_scene_drain_an_admitted_call() {
        let topology = Topology::admit(
            &[0, 0, 0, 3, 2, 0, -2, 0, 0, 1],
            &[0, 0, 0, 3, 0, 1],
            &[6],
            7,
        )
        .unwrap();
        let binding = SceneBinding(RwLock::new(Some(topology)));
        let (entered, active) = mpsc::sync_channel(0);
        let (release, resume) = mpsc::sync_channel(0);
        let (closing, started) = mpsc::sync_channel(0);
        let (closed, finished) = mpsc::channel();
        std::thread::scope(|scope| {
            let slot = &binding;
            let job = scope.spawn(move || {
                slot.call(|input| {
                    let mut masks = vec![0; input.pair_count];
                    entered.send(()).unwrap();
                    resume.recv_timeout(Duration::from_secs(5)).unwrap();
                    input.fill(&mut masks);
                    (1, masks)
                })
            });
            active.recv().unwrap();
            // 旧版本被取消时仍持有真实回调使用的读锁，第二次读取可以先完成，卸载则必须等待。
            let current_revision = 2;
            assert_eq!(binding.call(|input| input.pair_count), Some(10));
            assert!(matches!(
                binding.0.try_write(),
                Err(TryLockError::WouldBlock)
            ));
            scope.spawn(move || {
                closing.send(()).unwrap();
                slot.replace(None);
                closed.send(()).unwrap();
            });
            started.recv().unwrap();
            let pending = finished.recv_timeout(Duration::from_millis(100));
            release.send(()).unwrap();
            let (revision, masks) = job.join().unwrap().unwrap();
            assert_eq!(pending, Err(mpsc::RecvTimeoutError::Timeout));
            finished.recv().unwrap();
            assert_eq!(masks, [1, 7, 7, 1, 7, 7, 1, 1, 1, 1]);
            assert_ne!(revision, current_revision);
            assert!(binding.call(|_| ()).is_none());
        });
    }
}
