#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;

struct Boid {
    vec2 position;
    vec2 direction;
};

// Boids Data
layout(set = 0, binding = 0, std430) restrict buffer Boids {
    Boid boids[];
} boids;

// Boid Position Texture
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D position_texture;

// Trail Map Texture
layout(r32f, set = 2, binding = 0) uniform restrict image2D trail_texture;

// Parameters
layout(push_constant, std430) uniform Settings {
    // Map Settings
    vec2 map_size;
    float rounding;

    // Sensor Settings
    float sensorAngle;
    float sensorDistance;
    float sensorSize;
    float sensorThreshold;

    // Boid Settings
    float boidCount;
    float speed;
    float trailIncrease;
} settings;

float query_trail(Boid boid, vec2 sensorDirection) {
    vec2 sensorPosition = boid.position + sensorDirection * settings.sensorDistance;

    float sum = 0;

    // Sensor settings
    int halfSize = int(settings.sensorSize / 2);
    int adjustment = int(mod(settings.sensorSize, 2));

    ivec2 basePosition = ivec2(sensorPosition.x, sensorPosition.y);
    for (int offsetX = -halfSize ; offsetX < halfSize + adjustment; offsetX++)
    {
        for (int offsetY = -halfSize ; offsetY < halfSize + adjustment; offsetY++)
        {
            ivec2 position = basePosition + ivec2(offsetX, offsetY);

            if (position.x >= 0 && position.x < settings.map_size.x && position.y >= 0 && position.y < settings.map_size.y)
            {
                sum += imageLoad(trail_texture, position).r;
            }
        }
    }

    if (sum > settings.sensorThreshold)
        return sum;
    return 0.0;
}

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Rounded Rectangle Distance Field used as map boundaries
float roundedRectangleSDF(vec2 pos, vec2 size, float radius) {
    vec2 d = abs(pos - size) - vec2(size.x - radius, size.y - radius);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - radius;
}

void main() {
    if (gl_GlobalInvocationID.x >= settings.boidCount)
        return;    

    Boid boid = boids.boids[gl_GlobalInvocationID.x];

    // Calc sensor directions
    vec2 leftSensorDirection = boid.direction * mat2(cos(-settings.sensorAngle), -sin(-settings.sensorAngle), sin(-settings.sensorAngle), cos(-settings.sensorAngle));
    vec2 rightSensorDirection = boid.direction * mat2(cos(settings.sensorAngle), -sin(settings.sensorAngle), sin(settings.sensorAngle), cos(settings.sensorAngle));

    // Query boid sensors
    float left = query_trail(boid, leftSensorDirection);
    float middle = query_trail(boid, boid.direction);
    float right = query_trail(boid, rightSensorDirection);

    float steerStrength = random(boid.position);

    if (middle > left && middle > right)
    {
        // Do nothing - Keep same direction
    }
    else
    {
        vec2 steerDirection = vec2(0.0, 0.0);

        // Steer randomly left or right
        if (middle < left && middle < right) {
            steerDirection = mix(leftSensorDirection, rightSensorDirection, step(random(boid.position), 0.5));
        }
        // Steer left
        else if (left > right) {
            steerDirection = leftSensorDirection;
        }
        // Steer right
        else if (right > left) {
            steerDirection = rightSensorDirection;
        }

        // Check if steering is needed
        if (length(steerDirection) > 0.0) {
            vec2 steering = normalize(steerDirection - boid.direction) * steerStrength;
            boid.direction = normalize(boid.direction + steering);
        }
    } 

    // Move boid into direction
    vec2 updatedPosition = boid.position + boid.direction * settings.speed;

    // Check if new position is outside boundaries
    if (roundedRectangleSDF(updatedPosition, settings.map_size / 2.0, settings.rounding) > 0.001)
    {
        // Choose random new direction
        float randomAngle = random(boid.direction) * 6.28318530718;
        boid.direction = vec2(cos(randomAngle), sin(randomAngle));
    }
    else
    {
        // Get pixel position for texture update
        ivec2 pixelCoord = ivec2(updatedPosition);

        // Increase pheromone value at current position
        vec4 pheromones = imageLoad(trail_texture, pixelCoord);
        pheromones.r += settings.trailIncrease;
        imageStore(trail_texture, pixelCoord, pheromones);
    
        // Save current location in texture
        imageStore(position_texture, pixelCoord, vec4(1.0, 1.0, 1.0, 1.0));
        
        // Update boid position
        boid.position = updatedPosition;
    }

    // Write changes back to boid
    boids.boids[gl_GlobalInvocationID.x] = boid;
}