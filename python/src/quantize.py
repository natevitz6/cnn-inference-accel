import torch

def quantize_tensor(tensor, num_bits=8):
    """
    Quantize tensor to fixed-point signed int.
    For weights (symmetric quantization).
    Returns quantized tensor and scale factor.
    """
    qmin = -2**(num_bits - 1)
    qmax = 2**(num_bits - 1) - 1
    min_val = tensor.min()
    max_val = tensor.max()

    max_abs = max(abs(min_val.item()), abs(max_val.item()))
    scale = max_abs / qmax if max_abs != 0 else 1.0

    tensor_int = torch.clamp((tensor / scale).round(), qmin, qmax).to(torch.int)
    return tensor_int, scale


def quantize_bias_tensor(bias_tensor, input_scale, weight_scale, num_bits=32):
    """
    Quantize bias using input_scale * weight_scale.
    This keeps bias in the same domain as MAC results.
    """
    qmin = -2**(num_bits - 1)
    qmax = 2**(num_bits - 1) - 1
    scale = input_scale * weight_scale

    tensor_int = torch.clamp((bias_tensor / scale).round(), qmin, qmax).to(torch.int32)
    return tensor_int, scale


def compute_scale_shift(real_scale, scale_bits=16, max_shift=31):
    """
    Convert floating-point requant scale to integer scale + shift.
    scale_int fits into 'scale_bits'.
    """
    for shift in range(max_shift):
        scale_int = int(round(real_scale * (1 << shift)))
        if scale_int < (1 << scale_bits):
            return scale_int, shift
    raise ValueError("Cannot represent scale factor in given bit-width")


def quantize_model_weights(model, num_bits=8, bias_bits=32):
    """
    Quantize all parameters of model.
    - Weights: 8-bit
    - Biases: 32-bit with (input_scale * weight_scale)
    Returns dict with quantized tensors, scales, and shift params.
    """
    quantized_params = {}
    layer_scales = {}

    # Store per-layer input scales (start with 1.0 for first layer)
    prev_output_scale = 1.0

    for name, param in model.named_parameters():
        if "weight" in name:
            q_w, w_scale = quantize_tensor(param.data, num_bits)
            quantized_params[name] = {"quantized": q_w.cpu(), "scale": w_scale}
            layer_scales[name] = (prev_output_scale, w_scale)

        elif "bias" in name:
            # Match this bias with its corresponding weight
            weight_name = name.replace("bias", "weight")
            if weight_name not in quantized_params:
                raise RuntimeError(f"Weight for {name} not quantized yet")

            in_scale, w_scale = layer_scales[weight_name]
            q_b, b_scale = quantize_bias_tensor(param.data, in_scale, w_scale, num_bits=bias_bits)
            quantized_params[name] = {"quantized": q_b.cpu(), "scale": b_scale}

            # Now compute requantization scale for this layer’s output
            # (output_scale / (in_scale * w_scale))
            out_scale = 1.0  # assume we want next layer activations normalized ~8-bit
            real_requant_scale = out_scale / (in_scale * w_scale)
            scale_int, shift = compute_scale_shift(real_requant_scale, scale_bits=16)

            quantized_params[name]["requant"] = {
                "real_scale": real_requant_scale,
                "scale_int": scale_int,
                "shift": shift,
            }

            # Pass this scale to next layer as "input_scale"
            prev_output_scale = out_scale

    return quantized_params
