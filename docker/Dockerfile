FROM kalilinux/kali-rolling:latest

RUN apt-get update \
&&  apt-get install metasploit-framework -y \
&&  apt-get install python2 -y
RUN apt-get -y install supervisor && \
  mkdir -p /var/log/supervisor && \
  mkdir -p /etc/supervisor/conf.d
ADD supervisor.conf /etc/supervisor.conf
EXPOSE 3333 4444 2222
CMD ["supervisord", "-c", "/etc/supervisor.conf"]
