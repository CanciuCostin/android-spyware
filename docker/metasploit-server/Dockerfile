# SonarQube: Use specific version tag instead of :latest
FROM kalilinux/kali-rolling:2024.4

# SonarQube: Combine all RUN commands + cleanup + create directories
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        metasploit-framework \
        python2 \
        supervisor \
    && mkdir -p /var/log/supervisor /etc/supervisor/conf.d \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY supervisor.conf /etc/supervisor.conf
EXPOSE 3333 4444 2222
CMD ["supervisord", "-c", "/etc/supervisor.conf"]
