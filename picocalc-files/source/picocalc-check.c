#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <stdint.h>

#define I2C_BUS "/dev/i2c-2"  // I2C Bus (choose i2c-0 or i2c-1 based on your device)
#define I2C_ADDR 0x1f        // Slave device address

int i2c_read(int file, uint8_t reg_addr) {
    uint8_t buf[1] = {0};

    // Write register address
    if (write(file, &reg_addr, 1) != 1) {
        perror("PicoCalc not switched on, or Lyra not installed");
        return -1;
    }

    // Read data from the slave device
    if (read(file, buf, 1) != 1) {
        perror("Failed to read from device");
        return -1;
    }

    printf("PicoCalc keyboard version: 0x%02x\n", buf[0]);
    return buf[0];
}


int main() {
    int file;

    // Open the I2C bus
    if ((file = open(I2C_BUS, O_RDWR)) < 0) {
        perror("Failed to open I2C bus");
        return 1;
    }

    // Set the slave device address
    if (ioctl(file, I2C_SLAVE, I2C_ADDR) < 0) {
        perror("Failed to set I2C address, incorrect dtb loaded?");
        close(file);
        return 1;
    }

    // Read firmware version of PicoCalc keyboard so we know the lyra is installed.
    if (i2c_read(file, 0x01) < 0) {
        return 1;
    }

    // Close the I2C device
    close(file);

    return 0;
}
