FROM python:3.10-bullseye AS spark-base

ARG SPARK_MAJOR_VERSION=3.5
ARG SPARK_VERSION=3.5.2
ARG ICEBERG_VERSION=1.6.1
ARG HIVE_VERSION=4.0.0
ARG POSTGRES_JDBC_VERSION=42.6.0

ARG SCALAR_VERSION=2.12.20
ARG CLICKHOUSE_JDBC_VERSION=0.6.5
ARG CLICKHOUSE_RUNTIME_VERSION=0.8.0

# Install tools required by the OS
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      sudo \
      curl \
      vim \
      unzip \
      rsync \
      openjdk-11-jdk \
      build-essential \
      software-properties-common \
      ssh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# Setup the directories for our Spark and Hadoop installations
ENV SPARK_HOME=${SPARK_HOME:-"/opt/spark"}
ENV HADOOP_HOME=${HADOOP_HOME:-"/opt/hadoop"}

RUN mkdir -p ${HADOOP_HOME} && mkdir -p ${SPARK_HOME}
WORKDIR ${SPARK_HOME}

# Download and install Spark
RUN curl https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz -o spark-${SPARK_VERSION}-bin-hadoop3.tgz \
 && tar xvzf spark-${SPARK_VERSION}-bin-hadoop3.tgz --directory /opt/spark --strip-components 1 \
 && rm -rf spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Download iceberg spark runtime
RUN curl https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-${SPARK_MAJOR_VERSION}_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-${SPARK_MAJOR_VERSION}_2.12-${ICEBERG_VERSION}.jar -Lo /opt/spark/jars/iceberg-spark-runtime-${SPARK_MAJOR_VERSION}_2.12-${ICEBERG_VERSION}.jar

# Download clickhouse spark runtime
RUN curl https://repo1.maven.org/maven2/com/clickhouse/spark/clickhouse-spark-runtime-3.5_2.12/0.8.0/clickhouse-spark-runtime-3.5_2.12-0.8.0.jar -Lo /opt/spark/jars/clickhouse-spark-runtime-3.5_2.12-0.8.0.jar
# Download clickhouse client
RUN curl https://repo1.maven.org/maven2/com/clickhouse/clickhouse-client/0.6.5/clickhouse-client-0.6.5.jar -Lo  /opt/spark/jars/clickhouse-client-0.6.5.jar

# Download scalar
RUN curl https://repo1.maven.org/maven2/org/scala-lang/scala-library/2.12.20/scala-library-2.12.20.jar -Lo  /opt/spark/jars/scala-library-2.12.20.jar

# Download hive metastore
RUN curl https://repo1.maven.org/maven2/org/apache/hive/hive-metastore/${HIVE_VERSION}/hive-metastore-${HIVE_VERSION}.jar -Lo /opt/spark/jars/hive-metastore-${HIVE_VERSION}.jar

# Download Postgres JDBC driver
RUN curl https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar -Lo /opt/spark/jars/postgresql-${POSTGRES_JDBC_VERSION}.jar

# Download ClickHouse JDBC driver
RUN curl https://github.com/ClickHouse/clickhouse-java/releases/download/v${CLICKHOUSE_JDBC_VERSION}/clickhouse-jdbc-${CLICKHOUSE_JDBC_VERSION}-all.jar -Lo /opt/spark/jars/clickhouse-jdbc-${CLICKHOUSE_JDBC_VERSION}-all.jar

FROM spark-base AS pyspark

# Install python deps
COPY requirements/requirements.txt .
RUN pip3 install -r requirements.txt

# Setup Spark related environment variables
ENV PATH="/opt/spark/sbin:/opt/spark/bin:${PATH}"
ENV SPARK_MASTER="spark://spark-master:7077"
ENV SPARK_MASTER_HOST=spark-master
ENV SPARK_MASTER_PORT=7077
ENV PYSPARK_PYTHON=/usr/bin/python3

# Copy the default configurations into $SPARK_HOME/conf
COPY conf/spark-defaults.conf "$SPARK_HOME/conf"

RUN chmod u+x /opt/spark/sbin/* && \
    chmod u+x /opt/spark/bin/*

ENV PYTHONPATH=$SPARK_HOME/python/:$PYTHONPATH

# Copy appropriate entrypoint script
COPY entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
