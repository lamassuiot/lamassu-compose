FROM envoyproxy/envoy-dev@sha256:1535220d85f67284e9c69bef2cee4b1f3c4953258e75c2ccfce8d33fb8991b61

RUN apt-get update \
    && apt-get install --no-install-recommends -y curl \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

#
# for discussion on jaeger binary compatibility, and the source of the file, see here:
#  https://github.com/envoyproxy/envoy/issues/11382#issuecomment-638012072
#
RUN echo "4a7d17d4724ee890490bcd6cfdedb12a02316a3d33214348d30979abd201f1ca /usr/local/lib/libjaegertracing_plugin.so" > /tmp/checksum \
         && curl -Ls https://github.com/envoyproxy/misc/releases/download/jaegertracing-plugin/jaegertracing-plugin-centos.tar.gz \
              | tar zxf - -C /usr/local/lib \
         && mv /usr/local/lib/libjaegertracing.so.0.4.2 /usr/local/lib/libjaegertracing_plugin.so \
         && sha256sum -c /tmp/checksum \
         && rm /tmp/checksum 

#envsubst

RUN apt-get update && \
    apt-get install gettext -y

COPY config.yaml /tmpl/envoy.yaml.tmpl
COPY docker-entrypoint.sh /

RUN chmod 500 /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]