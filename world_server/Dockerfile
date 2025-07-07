FROM shabaw/love:latest AS build
RUN mkdir /usr/src/app
WORKDIR /usr/src/app
COPY . ./

CMD [ "love", ".", "8081" ]
EXPOSE 8081