<h1>ML-Accel: CNN Accelerator for MNIST</h1>
<p>This project implements a convolutional neural network (CNN) accelerator for the MNIST dataset.<br>
The design combines <strong>Python-based training and quantization</strong> with a <strong>Verilog hardware pipeline</strong> for inference.</p>

<h2>Project Overview</h2>
<ul>
  <li>Train a CNN on the MNIST dataset using PyTorch.</li>
  <li>Quantize the trained weights and biases to fixed-point representations (weights: int8, biases: int32 accumulator scale).</li>
  <li>Export quantized parameters to <code>.hex</code> files for hardware use.</li>
  <li>Implement a pipelined accelerator in Verilog that performs inference using the quantized model.</li>
  <li>Each architectural module was carefully verified and sized for int8 activations, int8 weights, and int32 accumulators.</li>
</ul>
<p>The goal is to demonstrate the complete flow from training a model in software to deploying it on hardware.</p>

<h2>CNN Architecture &amp; Parameters</h2>
<ul>
  <li><strong>Learning Rate</strong>: 0.001</li>
  <li><strong>Batch Size</strong>: 64</li>
  <li><strong>Epochs</strong>: 10</li>
  <li><strong>Input</strong>: 28&times;28 pixels, grayscale (0-255)</li>
  <li><strong>Output</strong>: 0-9 [Length 10 array]</li>
  <li><strong>Python Model</strong>: Optimizer = Adam, Loss = CrossEntropyLoss</li>
</ul>
<p>Layer Structure:</p>
<ul>
  <li>Conv Layer 1: 1 input, 16 output, 3&times;3 kernel, padding=1</li>
  <li>ReLU</li>
  <li>MaxPool 1: 2&times;2 kernel, stride=2</li>
  <li>Conv Layer 2: 16 input, 32 output, 3&times;3 kernel, padding=1</li>
  <li>ReLU</li>
  <li>MaxPool 2: 2&times;2 kernel, stride=2</li>
  <li>Linear layer 1: 32&times;7&times;7=1568 &rarr; 128 outputs</li>
  <li>Linear layer 2: 128 &rarr; 10 outputs</li>
</ul>

<h3>Layer Parameters</h3>
<table>
<thead>
<tr>
<th>Layer</th>
<th>Input Shape</th>
<th>Output Shape</th>
<th>Weights</th>
<th>Biases</th>
<th>Total Params</th>
</tr>
</thead>
<tbody>
<tr>
<td>Conv1 (3×3, 1→16)</td>
<td>1×28×28</td>
<td>16×28×28</td>
<td>144</td>
<td>16</td>
<td>160</td>
</tr>
<tr>
<td>ReLU1</td>
<td>16×28×28</td>
<td>16×28×28</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>MaxPool1 (2×2)</td>
<td>16×28×28</td>
<td>16×14×14</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>Conv2 (3×3,16→32)</td>
<td>16×14×14</td>
<td>32×14×14</td>
<td>4608</td>
<td>32</td>
<td>4640</td>
</tr>
<tr>
<td>ReLU2</td>
<td>32×14×14</td>
<td>32×14×14</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>MaxPool2 (2×2)</td>
<td>32×14×14</td>
<td>32×7×7</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>Flatten</td>
<td>32×7×7=1568</td>
<td>1568</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>Linear1 (1568→128)</td>
<td>1568</td>
<td>128</td>
<td>200704</td>
<td>128</td>
<td>200832</td>
</tr>
<tr>
<td>Linear2 (128→10)</td>
<td>128</td>
<td>10</td>
<td>1280</td>
<td>10</td>
<td>1290</td>
</tr>
</tbody>
</table>

<h2>Features</h2>
<ul>
  <li><strong>PyTorch Training</strong>: Standard CNN trained on MNIST.</li>
  <li><strong>Weight/Bias Export</strong>: Quantized weights (int8) and biases (int32) exported to <code>.hex</code> files for Verilog hardware.</li>
  <li><strong>Requantization Support</strong>: Scale and shift values for fixed-point conversions.</li>
  <li><strong>Verilog Hardware Pipeline</strong>:
    <ul>
      <li>Modular implementation: streaming input, window generation, convolution, activation, pooling, fully-connected, and output stages.</li>
      <li>Parameterized bit widths (activations: int8, weights: int8, biases: int32).</li>
      <li>Requantization modules resize intermediate and final activations.</li>
    </ul>
  </li>
  <li><strong>Integration Pipeline</strong>: Layer-by-layer pipelined execution of quantized CNN.</li>
</ul>

<h2>Folder and File Overview</h2>
<h3>Python Scripts</h3>
<ul>
  <li><code>train_mnist.py</code>: Trains the CNN on MNIST using PyTorch.</li>
  <li><code>quantize.py</code>: Quantizes model weights and biases to int8 and int32.</li>
  <li><code>convert_to_hex.py</code>: Converts quantized parameters to <code>.hex</code> files for hardware.</li>
  <li><code>export_weights.py</code>: Wrapper for full pipeline of quantization + exporting.</li>
</ul>
<h3>Model</h3>
<ul>
  <li><code>best_mnist_cnn.pth</code>: Saved PyTorch model checkpoint.</li>
  <li><code>weights/</code>: Folder of exported quantized weights/biases in hex format.</li>
</ul>
<h3>Verilog Source</h3>
<ul>
  <li><code>conv1_block.sv</code>: First convolutional layer.</li>
  <li><code>conv2_block.sv</code>: Second convolutional layer.</li>
  <li><code>linear_layer1.sv</code>: Fully connected layer.</li>
  <li><code>requantize.sv</code>: Scale/shift for fixed-point activations.</li>
  <li><code>top.sv</code>: Pipeline integration of all modules.</li>
</ul>

<h2>Hardware Module Breakdown</h2>
<table>
<thead>
<tr>
<th>Module</th>
<th>Inputs (Format)</th>
<th>Outputs (Format)</th>
<th>Computation Function</th>
</tr>
</thead>
<tbody>
<tr>
<td>tb_cnn</td>
<td>28x28 image, 8b pixels</td>
<td>10 class scores, 32b</td>
<td>End-to-end testbench: streams image; reads out result</td>
</tr>
<tr>
<td>image_streamer</td>
<td>28x28 image, 8b pixels</td>
<td>1 pixel, 8b</td>
<td>Streams pixels, supporting SAME padding</td>
</tr>
<tr>
<td>linebuf3</td>
<td>1 pixel, 8b</td>
<td>3x3 window, 8b pixels</td>
<td>Converts stream to window; pads edges if needed</td>
</tr>
<tr>
<td>conv1_layer</td>
<td>3x3 window, 8b</td>
<td>16 values, 32b</td>
<td>Convolution using 16 int8 filters, int32 bias, MACs</td>
</tr>
<tr>
<td>requantize1</td>
<td>16 values, 32b</td>
<td>16 values, 8b</td>
<td>Integer scale/shift conversion (32b→8b)</td>
</tr>
<tr>
<td>relu1</td>
<td>16 values, 8b</td>
<td>16 values, 8b, all ≥0</td>
<td>Applies ReLU activation</td>
</tr>
<tr>
<td>maxpool1</td>
<td>16 values, 8b, all ≥0</td>
<td>16 values, 8b, all ≥0</td>
<td>Finds max in each 2x2 window</td>
</tr>
<tr>
<td>conv2_layer, etc.</td>
<td>As above, expanded for 32 filters</td>
<td>As above, expanded for 32 filters</td>
<td>Second convolution, pooling, etc.</td>
</tr>
<tr>
<td>flatten</td>
<td>32×7×7 array, 8b</td>
<td>1568-long vector, 8b</td>
<td>Flattens feature map for FC layers</td>
</tr>
<tr>
<td>linear1</td>
<td>1568-long vector, 8b</td>
<td>128 neurons, 32b</td>
<td>Multiplies by weights, adds biases, outputs activations</td>
</tr>
<tr>
<td>requantize3, relu3</td>
<td>128 neurons, 32b/8b</td>
<td>128 neurons, 8b, all ≥0</td>
<td>Requantizes, applies ReLU</td>
</tr>
<tr>
<td>linear2</td>
<td>128 neurons, 8b</td>
<td>10 class scores, 32b</td>
<td>Final classification via fully connected layer</td>
</tr>
</tbody>
</table>
<p>Full per-module explanations, inputs/outputs, and computation flows are provided in module documentation. Key modules support pipeline-ready streaming and parallel processing where applicable.</p>

<h2>Data Formatting and Quantization Details</h2>
<ul>
  <li><strong>Input Pixels:</strong> 8 bits, int8 (support for zero-point/center)</li>
  <li><strong>Weights:</strong> int8 (8 bits fixed-point)</li>
  <li><strong>Biases:</strong> int32 accumulator scale (export as 32-bit values in hex)</li>
  <li><strong>Accumulators (MAC):</strong> 32 bits signed</li>
  <li><strong>Intermediate activations (feature maps):</strong> int8 after requantization</li>
  <li><strong>Layer Output Sizes:</strong>
    <ul>
      <li>Conv1: 16×28×28</li>
      <li>MaxPool1: 16×14×14</li>
      <li>Conv2: 32×14×14</li>
      <li>MaxPool2: 32×7×7</li>
      <li>Flatten: 1568</li>
      <li>Fully Connected: 128</li>
      <li>Output: 10 scores</li>
    </ul>
  </li>
</ul>
