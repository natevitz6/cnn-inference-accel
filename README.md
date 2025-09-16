# ML-Accel: CNN Accelerator for MNIST

This project implements a convolutional neural network (CNN) accelerator for the MNIST dataset.  
The design combines **Python-based training and quantization** with a **Verilog hardware pipeline** for inference.

## Project Overview
- Train a CNN on the MNIST dataset using PyTorch.  
- Quantize the trained weights and biases to fixed-point representations.  
- Export quantized parameters to `.hex` files for hardware use.  
- Implement a pipelined accelerator in Verilog that performs inference using the quantized model.  

The goal is to demonstrate the complete flow from training a model in software to deploying it on hardware.

## Features
- **PyTorch Training**: Standard CNN trained on MNIST.
- **Weight Export**: Quantized weights and biases exported to `.hex` files.
- **Requantization Support**: Scale and shift factors applied during inference for fixed-point accuracy.
- **Verilog Hardware Pipeline**:
  - `conv1_block` and `conv2_block` modules for convolutional layers.
  - `linear_layer1` module for the fully connected layer.
  - `requantize` module applies scale/shift for intermediate outputs.
- **Parameterization**: Bit widths for activations, weights, and biases can be adjusted.
- **Integration Pipeline**: Supports layer-by-layer execution of CNN with quantized arithmetic.

## Folder and File Overview

### Python Scripts
- `train_mnist.py`: Trains the CNN on MNIST using PyTorch.
- `quantize.py`: Quantizes model weights and biases to fixed-point.
- `convert_to_hex.py`: Converts quantized parameters into `.hex` files for Verilog.
- `export_weights.py`: Wrapper script for quantization and hex export.

### Model
- `best_mnist_cnn.pth`: Saved PyTorch model checkpoint.
- `weights/`: Folder containing exported weight and bias `.hex` files.

### Verilog Source
- `conv1_block.sv`: First convolutional layer module.
- `conv2_block.sv`: Second convolutional layer module.
- `linear_layer1.sv`: Fully connected layer module.
- `requantize.sv`: Applies scale and shift factors for fixed-point inference.
- `top.sv`: Integrates all modules into a top-level accelerator pipeline.

