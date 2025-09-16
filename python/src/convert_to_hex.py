import os
import json

def weights_to_hexfile(tensor_int, filename, width_bits=8):
    """
    Write a quantized signed int tensor to hex file for FPGA.
    width_bits: bit width of each value (e.g., 8 or 32)
    """
    flat = tensor_int.flatten().cpu().numpy()
    max_val = 2**width_bits
    hex_digits = width_bits // 4  # number of hex digits per value

    with open(filename, 'w') as f:
        for val in flat:
            # Convert to two's complement
            if val < 0:
                val_tc = val + max_val
            else:
                val_tc = val
            val_hex = format(val_tc, f'0{hex_digits}x')
            f.write(val_hex + '\n')



def save_model_weights_hex(quantized_params, base_path="weights/"):
    """
    Save weights and biases to hex files.
    Also export scale/shift values to JSON.
    """
    os.makedirs(base_path, exist_ok=True)
    requant_info = {}

    for name, data in quantized_params.items():
        filename = base_path + name.replace(".", "_") + ".hex"
        tensor = data["quantized"]

        # 8-bit weights, 32-bit biases
        if "bias" in name:
            weights_to_hexfile(tensor, filename, width_bits=8)
        else:
            weights_to_hexfile(tensor, filename, width_bits=2)

        print(f"Saved {name} to {filename}")

        # Save scale/shift if available
        if "requant" in data:
            requant_info[name] = data["requant"]

    # Write requantization params to JSON
    with open(base_path + "requant_params.json", "w") as f:
        json.dump(requant_info, f, indent=2)
    print(f"Saved requant params to {base_path}requant_params.json")
