## Overview

This project describes how to create a Dotnet Core application using a VsCode dev container. It showcases various techniques to improve the development experience including:

* Creating the project without having Dotnet Core or any other dev dependencies installed on the dev workstation.
* Debugging.
* Building and running the service using docker-compose.
* Attaching the dev container to the already running container and controlling the running process.
* Uploading the project to Github.

The requirements for this guide are:

* WSL2 installed.
* A Linux disro installed on WSL2 whose filesystem will be where the project directory lives.
* Docker Desktop installed and configured to use Linux containers.

The Microsoft Dotnet Core Docker images already have Git installed so VsCode Git integration will work out of the box from the dev container.

## Steps to Create

### Creating the inital project

Create a project directory on your WSL2 filesystem.

Open the project directory in VsCode

Create readme.md file

Create Dockerfile

    FROM mcr.microsoft.com/dotnet/sdk:3.1

    WORKDIR /docker-dotnet

Add docker-compose.yml.

    version: "3.8"
    services:  
      docker-dotnet:
        build: ./
        tty: true
        stdin_open: true
        volumes:
          - ./:/docker-dotnet
          - /bin
          - /obj
    
Create .devcontainer.json

    {
       "dockerComposeFile": "./docker-compose.yml",
       "service": "docker-dotnet",
       "workspaceFolder": "/docker-dotnet"
    }

Reopen the project in a VsCode dev container by running the VsCode command `Remote-Containers: Reopen in Container`.

Create ASP Core project using `dotnet new webapi`.

Build the project using `dotnet build`.

Run the project using `dotnet run`.

VsCode will popup a message stating that the port the application is listening on has been automatically forwarded. Open your browser to `locahost:<port>/weatherforecast` on that port and after dismissing a possible certificate warning you should see a json response from the endpoint.

Add the port to the docker-compose service definition so that it will be forwarded when run via docker-compose. If you missed the popup the port that Dotnet is listening on will be output to the terminal after executing `dotnet run`.

    version: "3.8"
    services:  
      docker-dotnet:
        build: ./
        tty: true
        stdin_open: true
        ports:
            - 5000:5000
        volumes:
          - ./:/docker-dotnet
          - /bin
          - /obj

Exit the `dotnet run` command using `ctrl+C` and execute `dotnet watch run`. Refresh the browser page and ensure the api is still working.

In `WeatherForecastController.cs` replace `Summary = Summaries[rng.Next(Summaries.Length)]` with `Summary = "Scorching"`. In the terminal you should se `dotnet watch run` recompile and restart the service. Refreshing the browser you should `"Summary": "scorching"` in each response object.

### Debugging the project

Click the Extensions button in the VsCode navigation sidebar. Enter `C#` in the extensions search box to locate the `C# for Visual Studio Code` extension and install it into the dev container. After it has finished installing a VsCode popup will appear stating `Required assets to build and debug are missing, add them?`, select `Yes` and VsCode will add a suitably consifured `launch.json` to the project.

In `WeatherForecastController.cs` add a breakpoint to the `public IEnumerable<WeatherForecast> Get()` method. On the VsCode navigation sidebar press the `Run` button and on the Run pane launch configuration dropdown select the `.NET Core Attach` configurtion and press the green `Start Debugging` button.

VsCode will then display a dropdown asking you to select which process to debug. Select the one in the `debug` directory of your current project, this is _not_ the `dotnet watch run` process.

Refresh the browser to trigger the request, and the debugger will break at your breakpoint in the controller.

Detach the debugger and enter `ctrl+C` in the integrated terminal to stop `dotnet watch build`.

### Enable starting the service using docker-compose.

Currently the application can be run because we manually ran `dotnet build` and then `dotnet run` from within the dev container. Additional steps are necessary to enable the service to be rebuilt and run using docker-compose.

Add the following to the end of the `Dockerfile`

    COPY . .
    RUN dotnet restore

Add the following to the end of the service definition in `docker-compose.yml`

    command: dotnet run

In `Properties/launchSettings.json` locate the `Project` launch profile. In the `applicationUrl` setting replace instances of `localhost` with `*` e.g. `"applicationUrl": "https://*:5001;http://*:5000"`.

To test this close the project in VsCode (or reopen in WSL). In a terminal on the host workstation run `docker ps` to verify that the dev container has exited. In a browser navigate to `localhost:<port>/weatherforecast`, it should not be reachable.

In the same terminal navigate to the project directory and run `docker-compose up -d --build`. This will rebuild the container from scratch, copy the source files into the container, install all the dependencies and build and run the service. Once this has completed you will be able to navigate to `localhost:<port>/weatherforecast` and see the api response as before.

### Improve the experience connecting VsCode to an already running container

With the service run via `docker-compose up -d` opening the dev container in VsCode will cause VsCode to attach to the already running container. This is nice but the usefulness of this is limited since the terminal spawned by opening the VsCode dev container will not attach to the already running service process in the container. So if your container is already running `dotnet run` when you attach to it, you have no way to terminate this process and execute other commands, install packages and restart the server, and even if you could terminate the running server that would not be useful since that would cause the container to exit anyway, since that is the process that is keeping the container alive.

There is a solution to this that involves the use of `tmux`. `tmux` is a terminal multiplexer, which among other things enables processes to be spawned in one terminal and then attached to and controlled from another terminal.

First install `tmux` in the container by adding the following to the Dockerfile after the `FROM` line. Note that the shell initialisation script that this creates is designed to work specifically for Debian Linux containers which use `bash` as the default shell. A different initialisation may be required for alpine Linux containers using `ash`. 

    # Install tmux
    RUN apt-get update
    RUN apt-get install -y tmux
    
    # Create a shell initialisation script that checks whether the current shell is running
    # within a tmux session, and if not attaches to an existing session.
    RUN echo "if [ \"$TMUX\" = \"\" ]; then" >> ~/.bashrc
    RUN echo "tmux attach -t my_session" >> ~/.bashrc
    RUN echo "fi" >> ~/.bashrc

Then replace the `command` in `docker-compose.yml` with

    command: sh -c "tmux new -d -s my_session;
      tmux send-keys -t my_session dotnet Space run C-m;
      tmux attach -t my_session"

Then rebuild the dev container, exit from the dev container and launch the service from a terminal using `docker-compose up -d` and verify the application is running by opening it in a browser at `localhost:<port>`

Open the project dev container in VsCode. You will find the `dotnet run` process running in the integrated terminal in a `tmux` session. You can update the code and your changes will update in the running app, you can also exit the running `dotnet run` process using `ctrl+C` and run other commands and restart the service without exiting the container.

### Upload the project to Github

Since git is installed in the dev container the VsCode git integration will all be functional. On the VsCode navigation sidebar click the `Source Control` button and on the Source Control pane click `Initialize Repository`. VsCode provides no feedback that this has worked, but if in the terminal you execute `ls -a` you will see the `.git` directory has been created. At this point you may need to reload the window for VsCode to initialise the source control provider, you may also need to add a suitable `.gitignore` file. The node one from [here](https://github.com/github/gitignore) is suitable.

Commit the changes to any modified files, and then in the VsCode status bar click the `Publish to Github` button. Assuming you have a Github account, you will be prompted to select either a public or provide Github repository and the project will be uploaded.

## Conclusion

This process to construct the project takes a somewhat iterative approach, adding and testing functionality a bit at a time. There is a fair amount of complexity here and building the project up in this manner and testing at each stage affords the best chance of tracking down any issues if something doesn't work as expected. Once familiarity with the tools and configuration has been gained a project with this configuration can be more quickly constructed in one go.

## Notes

The script added to .bashrc has a conditional statement that looks wrong.

FROM mcr.microsoft.com/dotnet/sdk:3.1

RUN useradd -ms /bin/bash -u 1000 dotnet