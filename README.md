# Snake in bootloader for x86 (BIOS)
Prepared for the purposes of an article celebrating Programmer's Day 2023 on the technical blog of Asseco Poland.


## Tools
### Software
- nasm
- dd

### Hardware
- some kind of flash storage like pendrive
- some PC with x86 processor which has BIOS, or UEFI able to set BIOS Legacy mode.

## How to build and put into pendrive
As a first step, you need to prepare a USB flash drive with any partitioning tool to create a sample partition table. Next, build the snake program with the following command: ```nasm -f bin snake.asm -o snake.bin.``` 
Then, use `dd` to write the snake.bin file to the beginning of the disk: 
```dd of={disk} if=snake.bin.```