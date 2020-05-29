FROM kalilinux/kali-rolling:latest

RUN apt-get update \
&&  apt-get install metasploit-framework -y \
&&  apt-get install android-tools-adb android-tools-fastboot -y

EXPOSE 3333 4444
CMD [ "msfrpcd", "-U", "cool", "-P", "looc", "-f", "-p", "3333", "-a","0.0.0.0"]