# syntax=docker/dockerfile:1

FROM docker.io/i386/alpine:3.18.5
# Using 3.18.5: https://github.com/copy/v86/issues/1324
RUN apk add mkinitfs --no-cache --allow-untrusted --repository https://dl-cdn.alpinelinux.org/alpine/v3.19/main

ENV KERNEL=virt

# coreutils-doc is needed to have the man pages of command like `ls`, `cat`, `cp`, etc. (altough busybox is installed instead of coreutils)
# Possible fix in the future: switch to coreutils instead of busybox, but it will increase the image size
ENV ADDPKGS="python3 gcc musl-dev make docs micro busybox-extras e2fsprogs coreutils-doc bash musl musl-utils musl-locales tzdata lang kbd-bkeymaps"

ADD rootfs_overlay/ /

RUN apk add --no-cache openrc alpine-base agetty alpine-conf linux-$KERNEL linux-firmware-none $ADDPKGS


#RUN sed -i 's/getty 38400 tty1/agetty --autologin root tty1 linux/' /etc/inittab
RUN echo 'ttyS0::respawn:/sbin/agetty --autologin root -s ttyS0 115200 vt100' >> /etc/inittab
RUN sed 's@tty1::respawn:/sbin/getty 38400 tty1@@g' -i /etc/inittab
RUN echo 'tty1::respawn:/sbin/agetty --autologin root -s tty1 38400 tty1' >> /etc/inittab

#RUN echo 'tty1::respawn:/sbin/agetty -n -l /bin/autologin tty1 linux' >> /etc/inittab
RUN echo "root:toor" | chpasswd


RUN setup-keymap fr fr

# https://wiki.alpinelinux.org/wiki/Alpine_Linux_in_a_chroot#Preparing_init_services
RUN for i in devfs dmesg mdev hwdrivers; do rc-update add $i sysinit; done
RUN for i in hwclock modules sysctl hostname syslog bootmisc; do rc-update add $i boot; done
RUN rc-update add killprocs shutdown

# Generate initramfs with 9p modules
RUN mkinitfs -F "base virtio 9p" $(cat /usr/share/kernel/$KERNEL/kernel.release)

ADD hooks/post-install.sh /opt/post-install.sh
RUN chmod +x /opt/post-install.sh
RUN /opt/post-install.sh

