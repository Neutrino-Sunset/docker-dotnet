FROM mcr.microsoft.com/dotnet/sdk:3.1

RUN apt-get update
RUN apt-get install -y tmux

RUN echo "if [ \"$TMUX\" = \"\" ]; then" >> ~/.bashrc
RUN echo "tmux attach -t my_session" >> ~/.bashrc
RUN echo "fi" >> ~/.bashrc

WORKDIR /docker-dotnet

COPY . .

RUN dotnet restore



