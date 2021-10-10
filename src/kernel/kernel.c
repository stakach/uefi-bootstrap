#include <stddef.h>
#include <stdint.h>

// https://github.com/JSBattista/Characters_To_Linux_Buffer_THE_HARD_WAY/blob/master/display.c

#define DESIRED_HREZ            1024
#define DESIRED_VREZ             768

void drawTriangle(uint64_t lfb_base_addr, int center_x, int center_y, int width, uint32_t color ) {
    uint32_t* at = (uint32_t*)lfb_base_addr;
    int row, col;

    at += (DESIRED_HREZ * (center_y - width / 2) + center_x - width / 2);

    for (row = 0; row < width / 2; row++) {
        for (col = 0; col < width - row * 2; col++)
            *at++ = color;
        at += (DESIRED_HREZ - col);
        for (col = 0; col < width - row * 2; col++)
            *at++ = color;
        at += (DESIRED_HREZ - col + 1);
    }
};

typedef struct s_video_buffer {
	uint64_t frame_buffer_base;
	uint64_t frame_buffer_size;
} Video_Buffer;

void kernel_main() {
  Video_Buffer* video = (Video_Buffer*)0x100000;

  if (video->frame_buffer_base == 2147483648) {
    drawTriangle(video->frame_buffer_base, 1024 / 2, 768 / 2 - 25, 100, 0x00119911);
  } else {
    drawTriangle(2147483648, 1024 / 2, 768 / 2 - 25, 100, 0x00ff99ff);
  }

	while(1);
};
