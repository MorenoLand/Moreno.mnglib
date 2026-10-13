#ifndef MNG_H
#define MNG_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint8_t *png;
    size_t png_size;
    uint32_t delay_milliseconds;
} mng_frame;

typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t ticks_per_second;
    uint32_t nominal_layer_count;
    uint32_t nominal_frame_count;
    uint32_t nominal_play_time;
    uint32_t simplicity_profile;
    mng_frame *frames;
    size_t frame_count;
} mng_animation;

int mng_is_mng(const uint8_t *data, size_t length);
int mng_parse(const uint8_t *data, size_t length, mng_animation *animation);
void mng_animation_free(mng_animation *animation);
int mng_first_png_frame(const uint8_t *data, size_t length, uint8_t **png, size_t *png_size);
size_t mng_frame_index_at(const mng_animation *animation, uint64_t elapsed_milliseconds);

#ifdef __cplusplus
}
#endif

#endif
