# Assembly-Software-Renderer
My final project for CISP 310 (assembly).
A (work-in-progress) software renderer, supporting triangle rasterization, matrix multiplication, and makes (spotty) use SIMD operations. 
The purpose of the project was to gain more familiarity with assembly, especially SIMD operations. While an attempt was made to 


Things that could/will be added:
Fix fragment shader coefficients, normals and colors so that fragment shader can be interpolation.
Finish MVP implementation to include the w component and a custom view/projection matrix.
Seperate rasterization and fragment shading, use 2x2 blocks for fragment shader execution, to batch SIMD operations and to obtain dx and dy.
