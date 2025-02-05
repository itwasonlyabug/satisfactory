{ modulesPath, pkgs, lib, ... }:

let
  s3_save_bucket = "satisfactoryserversaves";
  
  autoshutdown_script_url = "https://raw.githubusercontent.com/itwasonlyabug/satisfactory/refs/heads/main/autoshutdown.sh";
  autoshutdown_webhook_token = "$(${pkgs.awscli2}/bin/aws ssm get-parameter --name 'discord' --query 'Parameter.Value' --output text)";

  satisfactory_home_dir = "/home/satisfactory";
  satisfactory_dir = "/var/lib/SatisfactoryDedicatedServer";
  satisfactory_install = "${pkgs.steamPackages.steamcmd}/bin/steamcmd +login anonymous +force_install_dir ${satisfactory_dir} +app_update 1690800 validate +quit";
  satisfactory_save_dir = "${satisfactory_home_dir}/.config/Epic/FactoryGame/Saved/SaveGames";
  satisfactory_dotsteam_dir = "${satisfactory_home_dir}/.steam/steam";
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
    home  = "${satisfactory_home_dir}";
    extraGroups = ["wheel"];
  };

  system.activationScripts.makeSatisfactoryDir = lib.stringAfter [ "var" ] ''
    mkdir -p ${satisfactory_dir} && chown satisfactory:users ${satisfactory_dir}
  '';

  systemd.services = {
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
    
    autoshutdown-init = {
      description = "Pull autoshutdown script";
      wants = [ "network-online.target"];
      enable = true;
      script = ''
        ${pkgs.wget}/bin/wget "${autoshutdown_script_url}" -O "${satisfactory_home_dir}/autoshutdown.sh"
        chmod +x "${satisfactory_home_dir}/autoshutdown.sh"
        '';
      serviceConfig = {
        Type = "oneshot";
      };
      wantedBy = [ "multi-user.target" ];
    };
    
    autoshutdown = {
      description = "Shutdown after 5 minutes of inactivity";
      wants = [ "network-online.target"];
      enable = true;
      script = "${satisfactory_home_dir}/autoshutdown.sh ${autoshutdown_webhook_token}";
      after = [ "satisfactory.service" "autoshutdown-init.service" ];
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
