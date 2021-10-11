#include <stddef.h>
#include <stdint.h>

// https://github.com/JSBattista/Characters_To_Linux_Buffer_THE_HARD_WAY/blob/master/display.c

#define DESIRED_HREZ 1024
#define DESIRED_VREZ 768

// https://forum.osdev.org/viewtopic.php?f=1&t=26796
void drawTriangle(uint64_t lfb_base_addr, int center_x, int center_y, int width, uint32_t color) {
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

typedef struct pixel_bitmask {
  uint32_t red_mask;
  uint32_t green_mask;
  uint32_t blue_mask;
  uint32_t reserved_mask;
} PixelBitmask;

typedef struct graphics_mode {
  uint32_t version;
  uint32_t horizontal_resolution;
  uint32_t vertical_resolution;
  uint32_t pixel_format;  // technically an enum
  PixelBitmask pixel_information;
  uint32_t pixels_per_scan_line;
} GraphicsMode;

typedef struct graphics_output {
  uint32_t max_mode;
  uint32_t mode;
  GraphicsMode *info;
  uint64_t size_of_info;
  uint64_t frame_buffer_base;
  uint64_t frame_buffer_size;
} GraphicsOutput;

typedef struct boot_info {
  // UEFI GraphicsOutputProtocolMode structure
  GraphicsOutput *video;

  // UEFI memory map
  void *memory_map;
  uint64_t memory_map_size;
  uint64_t memory_map_descriptor_size;
} BootInfo;

// location of the boot information (memory map and video buffer from bootloader)
// NOTE:: this data should be moved into the memory the kernel explicitly controls
// as currently its in a random location in memory
extern BootInfo* boot_info;

// Start and end addresses of the kernel in memory
// we can use these for memory mapping later
extern void* kernel_start;
extern void* kernel_end;

void kernel_main() {
  drawTriangle(boot_info->video->frame_buffer_base, 1024 / 2, 768 / 2 - 25, 100, 0x00119911);
	while(1);
};
