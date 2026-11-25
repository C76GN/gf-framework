//! The static method borrows immutable Variant arguments for one synchronous call.
//! Only registration uses godot-rust's main-thread tables. Workers use Godot's C ABI.
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

// Only function pointers cross threads. A writer drains all active calls during scene teardown.
static ABI: SceneBinding<Abi> = SceneBinding(RwLock::new(None));

struct SceneBinding<T>(RwLock<Option<T>>);

impl<T> SceneBinding<T> {
    fn replace(&self, binding: Option<T>) {
        *self.0.write().unwrap_or_else(|e| e.into_inner()) = binding;
    }

    fn call<R>(&self, operation: impl FnOnce(&T) -> R) -> Option<R> {
        let active = self.0.read().unwrap_or_else(|e| e.into_inner());
        active.as_ref().map(operation)
    }
}

pub(crate) fn register() {
    // SAFETY: The scene init hook runs on main after the internal class was registered.
    let engine = unsafe { sys::on_main() };
    let size = StringName::from("size");
    let resize = StringName::from("resize");
    let resolve = || unsafe {
        // Godot extension_api hashes for int size() and int resize(int).
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
    // SAFETY: ClassDB copies the descriptors before this call returns. VARARG selects varcall only.
    unsafe {
        (engine.classdb_register_extension_class_method)(
            sys::get_library(),
            GfSegmentVisibilityBackend::class_id().string_sys(),
            &info,
        );
    }
}

pub(crate) fn unregister() {
    ABI.replace(None);
}

// SAFETY: Godot supplies live arguments and an initialized return Variant and call-error slot.
// No argument pointer, result storage or instance is retained past this call.
unsafe extern "C" fn call(
    _: *mut c_void,
    _: sys::GDExtensionClassInstancePtr,
    args: *const sys::GDExtensionConstVariantPtr,
    argc: i64,
    result: sys::GDExtensionVariantPtr,
    error: *mut sys::GDExtensionCallError,
) {
    let completed = ABI.call(|abi| unsafe {
        (*error).error = sys::GDEXTENSION_CALL_OK;
        // Keep a live Variant in the result slot at every point where Rust code can unwind.
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
        unsafe { (*error).error = sys::GDEXTENSION_CALL_ERROR_INVALID_METHOD };
    }
}

impl Abi {
    unsafe fn compute(
        &self,
        args: &[sys::GDExtensionConstVariantPtr; 4],
        result: sys::GDExtensionVariantPtr,
    ) -> Result<(), Error> {
        // SAFETY: Check exact types before using internal getters. Inputs stay live and
        // read-only until the caller returns. Rust only sees bounded, non-null borrowed slices.
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

            // The result is distinct from every input. Construct only after all admission checks.
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

// SAFETY: The caller keeps the matching packed Variant alive and immutable for 'a.
// Godot's index-const returns its contiguous packed storage; index 0 is only valid if nonempty.
unsafe fn column<'a, T>(
    base: sys::GDExtensionTypePtr,
    size: Builtin,
    read: unsafe extern "C" fn(sys::GDExtensionConstTypePtr, i64) -> *const T,
    limit: usize,
) -> Result<&'a [T], Error> {
    let mut count = 0_i64;
    unsafe { size(base, ptr::null(), (&raw mut count).cast(), 0) };
    let count = usize::try_from(count).map_err(|_| Error::ERR_INVALID_PARAMETER)?;
    if count > limit {
        return Err(Error::ERR_INVALID_PARAMETER);
    }
    if count == 0 {
        return Ok(&[]);
    }
    let first = unsafe { read(base, 0) };
    if first.is_null() {
        return Err(Error::ERR_INVALID_PARAMETER);
    }
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
            // The previous revision is now cancelled while holding the same call guard
            // as the actual C callback. A second reader can still finish independently.
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
