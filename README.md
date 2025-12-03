# 2D Systolic Array Accelerators for CNN Inference

This repository contains the hardware and verification source code, along with the project poster, for the development of specialized **2D Systolic Array** variants designed to accelerate Convolutional Neural Network (CNN) inference.

The project focuses on developing high-performance and power-optimized hardware architectures to address the computational demands of deep learning workloads.

---

## Project Team

**Team Name: Clocked Out**

* Ahmet Emre Eser 
* Ashita Singh
* Devansh Gupta 
* Riyansh Chaturvedi 
* Rohan Nafde
* Shoumik Panandikar
  
---

## Repository Structure

The project files are organized to reflect the development phases and components:

* **`part1`**: Contains all files related to Vanilla version.
* **`part2`**: Contains all files related to Part 2.
* **`part3`**: Contains all files related to Part 3.
* **`poster`**: Contains the PDF of the project poster.
* **`alpha`**: Contains the sub-folders for the incremental development phases (Alpha 1-4).
    * **`alpha/alpha1`**: Files related to simultaneous accumulation.
    * **`alpha/alpha2`**: Files related to functional verification.
    * **`alpha/alpha3`**: Files related to unified memory optimization.
    * **`alpha/alpha4`**: Files related to circuit-level power optimizations.


```text
├── alpha/
│   ├── alpha1/                 # Files related to simultaneous accumulation.
│   ├── alpha2/                 # Files related to functional verification.
│   ├── alpha3/                 # Files related to unified memory optimization.
│   └── alpha4/                 # Files related to circuit-level power optimizations.
├── part1/                      # Contains all files related to Vanilla version.
│   ├── core/                   
│   ├── fifos/
│   ├── outputs/
│   ├── sfp/
│   ├── sram/
│   ├── systolic_array/
│   ├── tb/
│   ├── weights/
│   ├── acc_add.txt
│   ├── activation.txt
│   ├── compiled
│   │   ├── core_tb.vcd
│   └── filelist
├── part2/                      # Contains all files related to Part 2.
├── part3/                      # Contains all files related to Part 3.
└── poster/                     # Contains the PDF of the project poster.
```

---

## Project Motivation and Design Variants

This project develops three specialized 2-D systolic array variants:

### Base Versions

* **Vanilla (Weight Stationary - WS)**: The baseline architecture implements the fundamental **Weight Stationary (WS)** dataflow, primarily optimizing for weight reuse efficiency.
* **SIMD Enhanced (2/4-bit Precision)**: Features a **Single Instruction, Multiple Data (SIMD)** data path to support **2-bit and 4-bit** input precision, which increases throughput for quantized neural network operations.
    * Performance was measured on **VGGNet 16** with **4-bit** (85.360% accuracy on CIFAR 10) and **2-bit** (89.560% accuracy on CIFAR 10) Quantization Aware Training.
* **Unified Stationary (WS & OS)**: Implements a flexible structure supporting dynamic switching between **Weight Stationary (WS)** and **Output Stationary (OS)** dataflows, aiming for applicability across various computation patterns.

---

## Alphas

### Alpha 1: Simultaneous Accumulation

* **Concept**: We implemented **in-place accumulation** through the Special Function Processor (**SFP**) pipeline.
* **Implementation**: Each SFP lane holds three dedicated accumulator registers that store the running sum of partial sums (`psums`) from the MAC array via the Output FIFO (`OFIFO`), accumulating them internally.
* **Benefit**: Only the the running accumulated sum of psums is written to SRAM, which reduces memory traffic and eliminates intermediate writes.

### Alpha 2: Functional Verification

* **Concept**: To ensure the integrity of the systolic array, we employ a rigorous **hardware-software verification methodology**.
* **Implementation**: We utilize **random stimulus testing** where the array is fed random numerical inputs (weights and feature maps) spanning the full supported bit precision.
    * The Design Under Test (**DUT**) is implemented in **SystemVerilog**.
    * A **Golden Reference Model** concurrently calculates the expected output. The hardware result is then compared against the Golden Result to confirm functional correctness.
* **Command**: ```iverilog -o compiled -g2012 -f ./filelist```

### Alpha 3: Unified Memory

* **Concept**: In **Output Stationary mode**, the Partial Sum Memory (`pmem`) is bandwidth-heavy during accumulation but often idle during the initial weight loading phase.
* **Optimization**: We reuse the existing high-bandwidth **pmem (128-bit)** to store weights instead of adding a separate, dedicated Kernel Memory (`kmem`).
* **Benefit**: This removes the need for an additional 32-bit SRAM bank entirely[cite: 61]. Eliminating one SRAM block, which dominates silicon area, significantly reduces the **total hardware footprint and static power leakage**.

### Alpha 4: Circuit Level Power Optimizations

This phase focuses on saving dynamic power through two main circuit-level techniques[cite: 63]:

1.  **Data Gating** 
    * **Concept**: When either the weight (`w`) or activation (`x`) is zero, the output simplifies to the partial sum (`psum`), making the MAC computation unnecessary.
    * **Action**: The MAC unit is bypassed using a **MUX** that forwards the `psum` to the output, while all inputs to the MAC are forced to zero.
    * **Benefit**: This prevents unnecessary switching activity within the MAC unit, saving **dynamic power**.

2.  **Clock Gating** 

    * **Concept**: Weight and load enable registers hold their values stable for long periods.
    * **Action**: When a register's load enable is inactive, **clock gating** prevents the flip-flops from toggling.
    * **Benefit**: This avoids the charging and discharging of internal capacitances, hence saving **dynamic power**.

---

## Performance on FPGA

The following table summarizes the performance metrics after mapping the design onto an **FPGA (Cyclone IV GX)**:

| Metric | Value |
| :--- | :--- |
| **Total OPs** | 128 |
| **Frequency** | 130.34 MHz |
| **Dynamic Power** | 31.24 mW |
| **TOPS** | 0.01668 |
| **TOPS/W** | 0.534 |
| **Total Logic Elements** | 22,556 |
| **Total Registers** | 12,146 |

---

## Git Ignore

A `.gitignore` file should be included in the root directory to exclude large and unnecessary simulation trace files, specifically `*.vcd`.
