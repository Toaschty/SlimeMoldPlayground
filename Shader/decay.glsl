#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// Trail Map Texture
layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D trail_texture;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D updated_trail_texture;

// Parameters
layout(push_constant, std430) uniform Settings {
    // Map Settings
    vec2 map_size;

    // Decay settings
    float blurSize;
    float lerpSpeed;
    float decayRate;
} settings;

void main() {
    if (gl_GlobalInvocationID.x < 0 || gl_GlobalInvocationID.x >= settings.map_size.x || gl_GlobalInvocationID.y < 0 || gl_GlobalInvocationID.y >= settings.map_size.y)
        return;

    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    
    float blurSum = 0.0;
    int sampleCount = 0;

    // Blur settings
    int halfSize = int(settings.blurSize / 2);
    int adjustment = int(mod(settings.blurSize, 2));

    for (int offsetY = -halfSize; offsetY < halfSize + adjustment ; ++offsetY)
    {
        for (int offsetX = -halfSize; offsetX < halfSize + adjustment ; ++offsetX)
        {
            ivec2 neighborCoord = pixelCoord + ivec2(offsetX, offsetY);

            if (neighborCoord.x >= 0 && neighborCoord.x < settings.map_size.x && neighborCoord.y >= 0 && neighborCoord.y < settings.map_size.y)
            {
                blurSum += imageLoad(trail_texture, neighborCoord).r;
                sampleCount++;
            }
        }
    }

    float blurredValue = blurSum / float(sampleCount);
    float lerpedValue = mix(imageLoad(trail_texture, pixelCoord).r, blurredValue, settings.lerpSpeed);
    float evaporatedValue = max(0, lerpedValue * settings.decayRate);

    // Save blurred and evaporated value into new trail map texture
    imageStore(updated_trail_texture, pixelCoord, vec4(evaporatedValue, 0.0, 0.0, 1.0));
}