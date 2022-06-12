FROM alpine:3.14

COPY src /client

WORKDIR /client

CMD ./broker-webapp
