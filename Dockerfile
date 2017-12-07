FROM openwhisk/nodejs6action

RUN apt-get update
RUN apt-get install -y zip git
