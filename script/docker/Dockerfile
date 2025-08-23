# 使用OpenJDK 17作为基础镜像
FROM openjdk:17-jdk-slim

# 设置工作目录
WORKDIR /ruoyi

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 创建应用目录
RUN mkdir -p /ruoyi/logs /ruoyi/temp /ruoyi/config

# 复制jar包
COPY ruoyi-admin/target/ruoyi-admin.jar /ruoyi/app.jar

# 复制配置文件
COPY ruoyi-admin/src/main/resources/application*.yml /ruoyi/config/

# 设置JVM参数
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:+UseContainerSupport"

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -Dspring.config.location=classpath:/,file:/ruoyi/config/ -jar /ruoyi/app.jar"]