FROM openjdk:11-jdk-slim-buster as BUILD

ARG SPRING_PROFILES_ACTIVE=default

RUN mkdir -p /usr/src/app
COPY .mvn/ /usr/src/app/.mvn
COPY mvnw /usr/src/app 
COPY pom.xml /usr/src/app 

WORKDIR /usr/src/app

#RUN mvn dependency:go-offline -B
RUN ./mvnw dependency:go-offline

COPY . /usr/src/app 

RUN ./mvnw clean install -DskipTests


FROM openjdk:11-jre
EXPOSE 8080

COPY --from=BUILD /usr/src/app/target/*.jar /opt/target/app.jar

WORKDIR /opt/target
RUN curl -sOL https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.4.2/applicationinsights-agent-3.4.2.jar

ENTRYPOINT ["java", "-javaagent:/opt/target/applicationinsights-agent-3.4.2.jar", "-jar", "app.jar"]