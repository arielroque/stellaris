FROM alpine:3.14

COPY src /stellaris

WORKDIR /stellaris

CMD ./stellaris-service
