{ modulesPath, pkgs, lib, ... }:

let
  s3_save_bucket = "satisfactoryserversaves";

  satisfactory_dir = "/var/lib/SatisfactoryDedicatedServer";
  satisfactory_install = "${pkgs.steamPackages.steamcmd}/bin/steamcmd +login anonymous +force_install_dir ${satisfactory_dir} +app_update 1690800 validate +quit";
  satisfactory_save_dir = "/home/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames";
  satisfactory_dotsteam_dir = "/home/satisfactory/.steam/steam";
  script_dir = "/home/satisfactory/scripts";
  discord_webhook_url = "";

  autoshutdown = pkgs.writeShellScriptBin "autoshutdown" ''
  #!/bin/sh
  BIN_PATH="/run/current-system/sw/bin"
  webhook() {
    URL=$discord_webhook_url
    DATA=$($BIN_PATH/cat << EOF
    {
      "username": "Ficsit Corp",
      "embeds": [{
        "title": "AWS Instance Status",
        "description": "Instance is shutting down...",
        "color": "45973"
      }]
    }
EOF
  )
  $BIN_PATH/curl -H "Content-Type: application/json" -X POST -d "$DATA" $URL
  }
  sumOfArrayElements() {
    BYTES=("$@")
    # returns the sum of all elements in an array
    SUM=$(IFS=+; echo "$((''${BYTES[*]}))")
    echo "$SUM"
  }
  
  checkForTraffic() {
    PORT_TO_CHECK=$1
    NUMBER_OF_CHECKS=$2
    
    for ((connections=0; connections<$NUMBER_OF_CHECKS; connections++)); do
        CHECK_CONNECTION_BYTES=$($BIN_PATH/ss -luna "( dport = :''${PORT_TO_CHECK} or sport = :''${PORT_TO_CHECK} )" | $BIN_PATH/awk -F ' ' '{s+=$2} END {print s}')
        CONNECTION_BYTES+=($CHECK_CONNECTION_BYTES)
    done
    
    CONNECTION_BYTES_SUM=$(sumOfArrayElements "''${CONNECTION_BYTES[@]}")
    echo "$CONNECTION_BYTES_SUM"
  }
  
  shutdownSequence() {
    echo "No activity detected. Shutting down."
    systemctl stop satisfactory.service
    systemctl start satisfactory-backup.service
    webhook
    sleep 10
    shutdown -h now
  }
  
  main(){
    IDLE_COUNTER=0
    TOTAL_IDLE_SECONDS=300
  
    GAME_PORT=7777
    CHECKS=5
  
    while [ $IDLE_COUNTER -lt $TOTAL_IDLE_SECONDS ]; do
        ACTIVE_CONNECTIONS=$(checkForTraffic $GAME_PORT $CHECKS)
  
        if [ "$ACTIVE_CONNECTIONS" -eq 0 ]; then
            IDLE_COUNTER=$((''$IDLE_COUNTER+1))
            echo "No connection detected."
        
        elif [ "$ACTIVE_CONNECTIONS" -gt 0 ]; then
  	  echo "Connection detected."
            IDLE_COUNTER=0
        fi
        sleep 1
  
    done
  
    shutdownSequence
  }
  
  main 
  '';
 
in

{
imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];
  ec2.hvm = true;
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    steamPackages.steamcmd
    awscli2
    libgcc
    gcc_multi
  ];

  networking.firewall = {
    allowedTCPPorts = [ 22 7777 ];
    allowedUDPPorts = [ 22 7777 15000 15777 ];
  };

  nixpkgs.config.allowUnfree = true;

  services.fail2ban = {
    enable = false;
    maxretry = 3;
  };

  users.users.satisfactory = {
    isNormalUser  = true;
    home  = "/home/satisfactory";
    extraGroups = ["wheel"];
  };

  system.activationScripts.makeSatisfactoryDir = lib.stringAfter [ "var" ] ''
    mkdir -p ${satisfactory_dir} && chown satisfactory:users ${satisfactory_dir}
  '';

  systemd.services = {
    #pull-scripts = {
    #  description = "Check if the scripts are present or clone the repo";
    #  enable = true;
    #  serviceConfig = {
    #    Type = "oneshot";
    #    ExecStart = "${pkgs.git}" clone https://github.com/itwasonlyabug/satisfactory.git "${script_dir}/";
    #  };
    #  wantedBy = [ "multi-user.target" ];
    #};

    satisfactory-init = {  
      description = "Prep SteamCMD and install Satisfactory";
      enable = true;
      wants = [ "network-online.target"];
      after = [ "syslog.target" "network.target" "nss-lookup.target" "network-online.target"];
      script = "${satisfactory_install}";
      serviceConfig = {
        Type = "oneshot";
        User = "satisfactory";
      };
    };
    
    satisfactory-load-saves = {  
      description = "Load existing (if any) Satisfactory saves";
      enable = true;
      wants = [ "network-online.target" ];
      requires = [ "satisfactory-init.service" ];
      after = [ "satisfactory-init.service" ];
      preStart = "mkdir -p ${satisfactory_save_dir}/server";
      script = "${pkgs.awscli2}/bin/aws s3 sync s3://${s3_save_bucket} ${satisfactory_save_dir}";
      serviceConfig = {
        Type = "oneshot";
        User = "satisfactory";
      };
    };
    
    satisfactory = {
      description = "Starts Satisfactory Dedicated Server";
      enable = true;
      restartIfChanged = true;
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      requires = [ "satisfactory-load-saves.service" ];
      after = [ "satisfactory-load-saves.service" ];
      preStart = ''
        sleep 10
        ln -sfv "${satisfactory_dotsteam_dir}"/linux64 "${satisfactory_dotsteam_dir}"/sdk64
        ${pkgs.patchelf}/bin/patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 ${satisfactory_dir}/Engine/Binaries/Linux/FactoryServer-Linux-Shipping
      '';
      script = ''
        ${satisfactory_dir}/Engine/Binaries/Linux/FactoryServer-Linux-Shipping FactoryGame -ServerQueryPort=15777 -BeaconPort=15000 -Port=7777 -log -unattended
      '';
      serviceConfig = {
        Restart = "always";
        User = "satisfactory";
        WorkingDirectory = "${satisfactory_dir}";
      };
      environment = {
        LD_LIBRARY_PATH="SatisfactoryDedicatedServer/linux64:SatisfactoryDedicatedServer/Engine/Binaries/Linux:SatisfactoryDedicatedServer/Engine/Binaries/ThirdParty/PhysX3/Linux/x86_64-unknown-linux-gnu";
      };
  };
    
    satisfactory-backup = {
      description = "Backup save state to S3";
      enable = true;
      serviceConfig = {
        User = "satisfactory";
      };
      script = ''
        ${pkgs.awscli2}/bin/aws s3 sync ${satisfactory_save_dir} s3://${s3_save_bucket}
      '';
      after = [ "satisfactory.service" ];
    };
    
    autoshutdown = {
      description = "Shutdown after 5 minutes of inactivity";
      wants = [ "network-online.target"];
      enable = true;
      script = "${autoshutdown}/bin/autoshutdown";
      after = [ "satisfactory.service" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
  
  systemd.timers.satisfactory-backup = {
    enable = true;
    wantedBy = [ "timers.target" ];
    partOf = [ "satisfactory.service" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Unit = "satisfactory-backup.service";
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
