#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Configuration parameters
#define SAMPLE_RATE 44100
#define BUFFER_SIZE 1024

// Delay line structure (single sample delay: z^-1)
typedef struct {
    double value;
} DelayLine;

// Complex number structure
typedef struct {
    double real;
    double imag;
} Complex;

// Delay line structure (single sample delay: z^-1)
typedef struct {
    double value;
} DelayLine;

// System state structure
typedef struct {
    double dly1;  // Delay1 state
    double dly2;  // Delay2 state
    double omega;  // Angular frequency for complex gain
    int n_mod;     // Modulation counter
} OOK_State;

// Complex multiply: out = a * b
Complex complex_multiply(Complex a, Complex b) {
    Complex result;
    result.real = a.real * b.real - a.imag * b.imag;
    result.imag = a.real * b.imag + a.imag * b.real;
    return result;
}

// Initialize OOK system
void ook_init(OOK_State *state, double frequency) {
    state->dly1 = 0.0;
    state->dly2 = 0.0;
    state->omega = 2.0 * M_PI * frequency / SAMPLE_RATE;
    state->n_mod = 0;
}

// Free OOK system (no cleanup needed for simple delays)
void ook_free(OOK_State *state) {
    // Nothing to free
}

// Reset OOK system
void ook_reset(OOK_State *state) {
    state->dly1 = 0.0;
    state->dly2 = 0.0;
    state->n_mod = 0;
}

// Process one sample through the OOK modulated waveform system
Complex ook_process(OOK_State *state, double input, double coeff, double gain_2cos, double gain_neg1) {
    Complex output;
    
    // Top path: input -> coeff gain -> dly1_times_complex
    double dly1_times_complex = input * coeff;
    
    // Bottom path: input -> Dly2 -> Gain_Neg1 -> minus_dly2
    double dly2_out = dly2;  // Read current dly2 value
    dly2 = input;            // Update dly2 with new input
    double minus_dly2 = dly2_out * gain_neg1;
    
    // Add: add_1 = dly1_times_complex + minus_dly2
    double add_1 = dly1_times_complex + minus_dly2;
    
    // Delay1: read then update
    double dly1_out = dly1;  // Read current dly1 value
    dly1 = add_1;            // Update dly1 with add_1
    
    // Complex gain calculation
    // Real part: dly1 * (-cos(omega * n))
    // Imaginary part: dly1 * (-sin(omega * n))
    double angle = omega * n_mod;
    
    // Real_Part_Gain_Complex: dly1 * -cos(omega)
    double real_gain_complex = dly1 * (-cos(angle)) * gain_2cos;
    
    // Imaginary_Part_Gain_Complex: dly1 * -sin(omega)
    double imag_gain_complex = dly1 * (-sin(angle)) * gain_2cos;
    
    // Final summation to get real and imag outputs
    output.real = real_gain_complex;
    output.imag = imag_gain_complex;
    
    // Increment modulation counter
    state->n_mod++;
    
    return output;
}

// Example usage and test
int main() {
    OOK_State state;
    
    // Parameters
    // Carrier frequency: 1000 Hz
    double carrier_freq = 1000.0;
    double omega = 2.0 * M_PI * carrier_freq / SAMPLE_RATE;
    double coeff = 0.5;
    double gain_2cos = 2.0;
    double gain_neg1 = -1.0;
    
    printf("OOK Modulated Waveform System\n");
    printf("Sample Rate: %d Hz\n", SAMPLE_RATE);
    printf("Carrier Frequency: %.1f Hz\n", carrier_freq);
    printf("Omega: %.6f rad/sample\n", omega);
    printf("Delay: z^-1 (single sample)\n\n");
    
    // Generate test signal: square wave for OOK modulation
    printf("Processing samples...\n");
    for (int i = 0; i < 200; i++) {
        // Simple square wave input (OOK pattern)
        double input = (i % 100 < 50) ? 1.0 : 0.0;
        
        Complex output = ook_process(input, coeff, gain_2cos, gain_neg1, omega);
        
        // Print every 10th sample
        if (i % 10 == 0) {
            printf("Sample %3d: Input=%.2f, Output=(%.4f, %.4f)\n", 
                   i, input, output.real, output.imag);
        }
    }
    
    printf("\nProcessing complete.\n");
    
    return 0;
}
