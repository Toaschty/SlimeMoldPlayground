#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

struct Boid {
    vec2 position;
    vec2 direction;
};

// Boids Data
layout(set = 0, binding = 0, std430) restrict buffer Boids {
    Boid boids[];
} boids;

// Generation Settings
layout(push_constant, std430) uniform Settings {
    vec2 map_size;
    float boidCount;
    float seed;
    bool centralizedSpawn;
} settings;

float random(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float random(float p) {
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

void main() {
    if (gl_GlobalInvocationID.x >= settings.boidCount)
        return;

    Boid boid = boids.boids[gl_GlobalInvocationID.x];

    // Generate random seed
    float seed = random(gl_GlobalInvocationID.xy + vec2(settings.seed));

    // Init boid position
    if (!settings.centralizedSpawn)
    {
        float random_x = random(gl_GlobalInvocationID.xy + vec2(seed)) * settings.map_size.x;
        float random_y = random(gl_GlobalInvocationID.xy + vec2(1.0 - seed)) * settings.map_size.y;

        boid.position = vec2(random_x, random_y);
    }
    else
    {
        boid.position = settings.map_size / 2.0;
    }

    // Init boid direction
    float randomAngle = random(seed) * 6.28318530718; // TWO_PI
    boid.direction = vec2(cos(randomAngle), sin(randomAngle));

    // Write changes back to boid
    boids.boids[gl_GlobalInvocationID.x] = boid;
}