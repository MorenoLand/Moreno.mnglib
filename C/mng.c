#include "mng.h"

#include <stdlib.h>
#include <string.h>

static const uint8_t mng_signature[8] = {0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
static const uint8_t png_signature[8] = {0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};

static uint32_t read_u32(const uint8_t *data) {
    return ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) | ((uint32_t)data[2] << 8) | data[3];
}

static int append_bytes(uint8_t **buffer, size_t *length, size_t *capacity, const uint8_t *data, size_t count) {
    if (count > SIZE_MAX - *length) return 0;
    size_t required = *length + count;
    if (required > *capacity) {
        size_t next = *capacity ? *capacity : 64;
        while (next < required) {
            if (next > SIZE_MAX / 2) {
                next = required;
                break;
            }
            next *= 2;
        }
        uint8_t *resized = (uint8_t *)realloc(*buffer, next);
        if (!resized) return 0;
        *buffer = resized;
        *capacity = next;
    }
    memcpy(*buffer + *length, data, count);
    *length = required;
    return 1;
}

static int parse_frame_delay(const uint8_t *data, size_t length, uint32_t *delay) {
    if (length == 0) return 0;
    size_t offset = 1;
    while (offset < length && data[offset] != 0) offset++;
    if (offset == length) return 0;
    offset++;
    if (offset >= length) return 0;
    int change = data[offset++];
    if (length - offset < 3) return 0;
    offset += 3;
    if (change == 0 || length - offset < 4) return 0;
    *delay = read_u32(data + offset);
    return change;
}

static int append_frame(mng_animation *animation, size_t *capacity, uint8_t *png, size_t png_size, uint32_t delay) {
    if (animation->frame_count == *capacity) {
        if (*capacity > SIZE_MAX / sizeof(*animation->frames) / 2) return 0;
        size_t next_capacity = *capacity ? *capacity * 2 : 8;
        mng_frame *frames = (mng_frame *)realloc(animation->frames, next_capacity * sizeof(*frames));
        if (!frames) return 0;
        animation->frames = frames;
        *capacity = next_capacity;
    }
    animation->frames[animation->frame_count].png = png;
    animation->frames[animation->frame_count].png_size = png_size;
    animation->frames[animation->frame_count].delay_milliseconds = delay;
    animation->frame_count++;
    return 1;
}

int mng_is_mng(const uint8_t *data, size_t length) {
    return data != NULL && length >= sizeof(mng_signature) && memcmp(data, mng_signature, sizeof(mng_signature)) == 0;
}

void mng_animation_free(mng_animation *animation) {
    if (!animation) return;
    for (size_t index = 0; index < animation->frame_count; index++) free(animation->frames[index].png);
    free(animation->frames);
    memset(animation, 0, sizeof(*animation));
}

int mng_parse(const uint8_t *data, size_t length, mng_animation *animation) {
    if (!animation) return 0;
    memset(animation, 0, sizeof(*animation));
    if (!mng_is_mng(data, length)) return 0;
    animation->ticks_per_second = 100;
    uint8_t *frame = NULL;
    size_t frame_size = 0;
    size_t frame_capacity = 0;
    size_t frames_capacity = 0;
    int in_png = 0;
    int has_default_ticks = 0;
    int has_next_ticks = 0;
    uint32_t default_ticks = 0;
    uint32_t next_ticks = 0;
    size_t offset = sizeof(mng_signature);
    while (offset < length) {
        if (length - offset < 12) goto fail;
        uint32_t data_length = read_u32(data + offset);
        if (data_length > length - offset - 12) goto fail;
        size_t chunk_length = (size_t)data_length + 12;
        const uint8_t *chunk_data = data + offset + 8;
        if (memcmp(data + offset + 4, "MHDR", 4) == 0) {
            if (data_length < 28) goto fail;
            animation->width = read_u32(chunk_data);
            animation->height = read_u32(chunk_data + 4);
            uint32_t ticks = read_u32(chunk_data + 8);
            if (ticks > 0) animation->ticks_per_second = ticks;
            animation->nominal_layer_count = read_u32(chunk_data + 12);
            animation->nominal_frame_count = read_u32(chunk_data + 16);
            animation->nominal_play_time = read_u32(chunk_data + 20);
            animation->simplicity_profile = read_u32(chunk_data + 24);
        } else if (memcmp(data + offset + 4, "FRAM", 4) == 0) {
            uint32_t delay_ticks = 0;
            int change = parse_frame_delay(chunk_data, data_length, &delay_ticks);
            if (change == 1) {
                next_ticks = delay_ticks;
                has_next_ticks = 1;
            } else if (change == 2) {
                default_ticks = delay_ticks;
                has_default_ticks = 1;
                has_next_ticks = 0;
            }
        }
        if (!in_png && memcmp(data + offset + 4, "IHDR", 4) == 0) {
            if (!append_bytes(&frame, &frame_size, &frame_capacity, png_signature, sizeof(png_signature))) goto fail;
            in_png = 1;
        }
        if (in_png) {
            if (!append_bytes(&frame, &frame_size, &frame_capacity, data + offset, chunk_length)) goto fail;
            if (memcmp(data + offset + 4, "IEND", 4) == 0) {
                uint32_t delay = 100;
                if (has_next_ticks || has_default_ticks) {
                    uint64_t ticks = has_next_ticks ? next_ticks : default_ticks;
                    uint64_t milliseconds = (ticks * 1000 + animation->ticks_per_second / 2) / animation->ticks_per_second;
                    delay = milliseconds > UINT32_MAX ? UINT32_MAX : (uint32_t)milliseconds;
                }
                if (!append_frame(animation, &frames_capacity, frame, frame_size, delay)) goto fail;
                frame = NULL;
                frame_size = 0;
                frame_capacity = 0;
                has_next_ticks = 0;
                in_png = 0;
            }
        }
        offset += chunk_length;
    }
    if (in_png || animation->frame_count == 0) goto fail;
    free(frame);
    return 1;
fail:
    free(frame);
    mng_animation_free(animation);
    return 0;
}

int mng_first_png_frame(const uint8_t *data, size_t length, uint8_t **png, size_t *png_size) {
    if (!png || !png_size) return 0;
    *png = NULL;
    *png_size = 0;
    mng_animation animation = {0};
    if (!mng_parse(data, length, &animation)) return 0;
    *png = (uint8_t *)malloc(animation.frames[0].png_size);
    if (!*png) {
        mng_animation_free(&animation);
        return 0;
    }
    memcpy(*png, animation.frames[0].png, animation.frames[0].png_size);
    *png_size = animation.frames[0].png_size;
    mng_animation_free(&animation);
    return 1;
}

size_t mng_frame_index_at(const mng_animation *animation, uint64_t elapsed_milliseconds) {
    if (!animation || animation->frame_count == 0) return SIZE_MAX;
    if (animation->frame_count == 1) return 0;
    uint64_t duration = 0;
    for (size_t index = 0; index < animation->frame_count; index++) duration = animation->frames[index].delay_milliseconds > UINT64_MAX - duration ? UINT64_MAX : duration + animation->frames[index].delay_milliseconds;
    if (duration == 0) return 0;
    uint64_t elapsed = elapsed_milliseconds % duration;
    for (size_t index = 0; index < animation->frame_count; index++) {
        if (elapsed < animation->frames[index].delay_milliseconds) return index;
        elapsed -= animation->frames[index].delay_milliseconds;
    }
    return animation->frame_count - 1;
}
