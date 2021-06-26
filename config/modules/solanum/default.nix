{ pkgs, lib, config, nodes, name, ... }:

with lib;

let
  certDir = "${config.security.acme.certs."${config.networking.fqdn}".directory}";
  dhParam = ./ffdhe4096.pem;

  isIPv6 = ip: builtins.length (lib.splitString ":" ip) > 2;
  optionalNull = val: ret: optionalString (val != null) ret;

  cfg = config.hackint.solanum;

in {
  options.hackint.solanum = with types; {
    enable = mkEnableOption "the Solanum IRC server";

    sid = mkOption {
      type = strMatching "^[0-9][0-9A-Z]{2}$";
      example = "42X";
      description = ''
        The unique server id of this server
      '';
    };

    description = mkOption {
      type = str;
      default = "Your admin was too lazy to write a description";
      description = ''
        A short message describing the server.
      '';
    };

    maxClients = mkOption {
      type = ints.positive;
      default = 8192;
      example = 16384;
      description = ''
        The maximum number of clients allowed to connect to the server.
        Affects ssld listeners as well as number of allowed open files.
      '';
    };

    isHub = mkOption {
      type = bool;
      default = false;
      example = true;
      description = ''
        Whether the server acts as a hub, as opposed to a leaf.
      '';
    };

    ssl = {
      ciphers = mkOption {
        type = listOf str;
        default = [
          "DHE-RSA-AES128-GCM-SHA256"
          "DHE-RSA-AES256-GCM-SHA384"
          "ECDHE-ECDSA-AES128-GCM-SHA256"
          "ECDHE-ECDSA-AES256-GCM-SHA384"
          "ECDHE-ECDSA-CHACHA20-POLY1305"
          "ECDHE-RSA-AES128-GCM-SHA256"
          "ECDHE-RSA-AES256-GCM-SHA384"
          "ECDHE-RSA-CHACHA20-POLY1305"
          "TLS_AES_128_GCM_SHA256"
          "TLS_AES_256_GCM_SHA384"
          "TLS_CHACHA20_POLY1305_SHA256"
        ];
        description = ''
          List of ciphers to accept on TLS sockets. Defaults to Mozilla Server Side TLS intermediate security.
          https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28recommended.29
        '';
      };
    };

    exempts = mkOption {
      type = listOf str;
      default = [];
      example = [
        "192.0.2.2/32"
        "2001:DB8:2::/64"
      ];
      description = ''
        List of hosts that are exempt from D-Lines and throttling.
      '';
    };

    opers = mkOption {
      description = ''
        Attribute set defining operators (O-line).
      '';
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = name;
            description = ''
              Account name used for opering.
            '';
          };
          hostmasks = mkOption {
            type = listOf str;
            description = ''
              List of hostmasks the operator is connecting from.
            '';
          };
          hashedPassword = mkOption {
            # TODO: match $\d$ as prefix
            type = str;
            description = ''
              Hashed password for opering, created using mkpasswd.
            '';
          };
          certificateFingerprint = mkOption {
            type = str;
            description = ''
              Fingerprint of the certificate used to authenticate the connection.
            '';
          };
          snomask = mkOption {
            type = strMatching "\\+[bcCdfknrsuxyZ]*";
            description = ''
              Server notice mask, see /quote help snomask.
            '';
            default = "+fsxZ";
            example = "+Zbfkrsuy";
          };
        };
      }));
    };

    classes = mkOption {
      description = ''
        Attribute set defining connection classes (Y-Line).
      '';
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = name;
            description = ''
              Name to assign the connection class.
            '';
          };
          maxConnections = mkOption {
            type = ints.positive;
            example = 8192;
            description = ''
              Maximum number of connections allowed in this class.
            '';
          };

          pingTime = mkOption {
            type = str;
            default = "2 minutes";
            example = "1 minute 30 seconds";
            description = ''
              Time for a connection to reply to a PING request, before they are dropped.
            '';
          };

          sendQ = mkOption {
            type = str;
            example = "100 kbytes";
            description = ''
              Amount of data a client can send, before they are dropped.
            '';
          };

          perIdent = mkOption {
            type = nullOr ints.positive;
            default = null;
            example = 3;
            description = ''
              Maximum number of connections sharing the same user@host.
              Unidented connections are counted as the same ident.
            '';
          };

          perIP = mkOption {
            type = nullOr ints.positive;
            default = null;
            example = 5;
            description = ''
              Maxium number of connections sharing the same host.
            '';
          };

          perCIDR = mkOption {
            type = nullOr ints.positive;
            default = null;
            example = 3;
            description = ''
              Maximum number of connections per defined subnet sizes.
            '';
          };

          ipv6SubnetSize = mkOption {
            type = nullOr (ints.between 0 128);
            default = null;
            example = 56;
            description = ''
              IPv6 subnet size considered for per CIDR limits.
            '';
          };

          ipv4SubnetSize = mkOption {
            type = nullOr (ints.between 0 32);
            default = null;
            example = 24;
            description = ''
              IPv4 subnet size considered for per CIDR limits.
            '';
          };

          maxAutoconn = mkOption {
            type = ints.between 0 1;
            example = 1;
            description = ''
              Number of servers to autoconnect to.
              Should be 0 for hubs, 1 for leafs.
            '';
          };

          autoconnFreq = mkOption {
            type = str;
            example = "5 minutes";
            description = ''
              Delay between attempts to autoconnect servers.
            '';
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {

    systemd.services.solanum = {
      after = [
        # Wait for wireguard tunnels to be up
        "network-online.target"
      ];
      serviceConfig = {
        # Allow access to certificates
        SupplementaryGroups = [ "acme" ];
      };
    };

    services.solanum = {
      enable = true;

      # Keep a buffer for server links, certificates and actual configuration
      openFilesLimit = cfg.maxClients + 128;

      motd = ''
                           __               __
                          / /_  ____ ______/ /__
                         / __ \/ __ `/ ___/ //_/
                        / / / / /_/ / /__/ ,<            __
                       /_/ /_/\__,_/\___/_/|_|  (*)___  / /_
                                               / / __ \/ __/
                                              / / / / / /_
                    http://www.hackint.org   /_/_/ /_/\__/
                    http://www.hackint.eu

        ======================================================================

      '';

      config = let
        others = mapAttrs (_: node: node.config) (removeAttrs nodes [ name ]);

        leafs = filterAttrs (_: host: !host.hackint.solanum.isHub) others;
        hubs = filterAttrs (_: host: host.hackint.solanum.isHub) others;
      in
      ''
        loadmodule "extensions/chm_operonly";
        loadmodule "extensions/extb_account";
        loadmodule "extensions/extb_canjoin";
        loadmodule "extensions/extb_channel";
        loadmodule "extensions/extb_extgecos";
        loadmodule "extensions/extb_oper";
        loadmodule "extensions/extb_realname";
        loadmodule "extensions/ip_cloaking_4.0";
        loadmodule "extensions/m_extendchans";
        loadmodule "extensions/m_findforwards";
        loadmodule "extensions/m_webirc";
        loadmodule "extensions/override";
        loadmodule "extensions/sno_farconnect";
        loadmodule "extensions/sno_globalnickchange";
        loadmodule "extensions/sno_globaloper";

        #loadmodule "extensions/chm_adminonly";
        #loadmodule "extensions/chm_nonotice";
        #loadmodule "extensions/chm_operpeace";
        #loadmodule "extensions/chm_sslonly";
        #loadmodule "extensions/createauthonly";
        #loadmodule "extensions/extb_combi";
        #loadmodule "extensions/extb_hostmask";
        #loadmodule "extensions/extb_server";
        #loadmodule "extensions/extb_ssl";
        #loadmodule "extensions/extb_usermode";
        #loadmodule "extensions/helpops";
        #loadmodule "extensions/hurt";
        #loadmodule "extensions/ip_cloaking";
        #loadmodule "extensions/m_identify";
        #loadmodule "extensions/m_locops";
        #loadmodule "extensions/no_kill_services";
        #loadmodule "extensions/no_oper_invis";
        #loadmodule "extensions/sno_whois";

        serverinfo {
          name = "${config.networking.fqdn}";
          sid = "${cfg.sid}";
          description = "${cfg.description}";

          network_name = "hackint";
          hub = ${if cfg.isHub then "yes" else "no"};

          ${concatMapStringsSep "\n" (address: "vhost6 = \"${address}\";" ) config.hackint.network.addresses6}
          ${concatMapStringsSep "\n" (address: "vhost = \"${address}\";" ) config.hackint.network.addresses4}
          vhost6 = "''${config.hackint.wireguard.address}";

          ssl_private_key = "${certDir}/key.pem";
          ssl_cert = "${certDir}/fullchain.pem";
          ssl_dh_params = "${dhParam}";
          ssl_cipher_list = "${concatStringsSep ":" cfg.ssl.ciphers}";
          ssld_count = 4;

          default_max_clients = ${toString cfg.maxClients};
          nicklen = 31;
        };

        admin {
          name = "hackint staff";
          description = "Ask in #hackint";
          email = "<mail@hackint.org>";
        };

        log {
          fname_userlog = "/dev/stdout";
          fname_fuserlog = "/dev/stdout";
          fname_operlog = "/dev/stdout";
          fname_foperlog = "/dev/stdout";
          fname_serverlog = "/dev/stdout";
          fname_klinelog = "/dev/stdout";
          fname_killlog = "/dev/stdout";
          fname_operspylog = "/dev/stdout";
          fname_ioerrorlog = "/dev/stderr";
        };

        ${concatMapStringsSep "\n" (class: ''
        class "${class.name}" {
          max_number = ${toString class.maxConnections};
          ping_time = ${class.pingTime};
          sendq = ${class.sendQ};
        ''
        + optionalNull class.perIdent "  number_per_ident = ${toString class.perIdent};\n"
        + optionalNull class.perIP "  number_per_ip_global = ${toString class.perIP};\n"
        + optionalNull class.perCIDR "  number_per_cidr = ${toString class.perCIDR};\n"
        + optionalNull class.ipv6SubnetSize "  cidr_ipv6_bitlen = ${toString class.ipv6SubnetSize};\n"
        + optionalNull class.ipv4SubnetSize "  cidr_ipv4_bitlen = ${toString class.ipv4SubnetSize};\n"
        + optionalNull class.maxAutoconn "  max_autoconn = ${toString class.maxAutoconn};\n"
        + optionalNull class.autoconnFreq "  connectfreq = ${class.autoconnFreq};\n"
        + ''
        };
        '') (attrValues cfg.classes)}

        listen {
          defer_accept = yes;

          # client ports
        	port = 6667;
          sslport = 6697, 9999;

          # server ports
          host = "''${config.hackint.wireguard.address}";
          sslport = 7000;
        };

        auth {
        	user = "*@*";
        	class = "users";
        };

        privset "operator" {
          privs =
            auspex:cmodes,
            auspex:hostname,
            auspex:oper,
            auspex:umodes,
            oper:admin,
            oper:cmodes,
            oper:general,
            oper:kill,
            oper:kline,
            oper:mass_notice,
            oper:message,
            oper:operwall,
            oper:privs,
            oper:remoteban,
            oper:resv,
            oper:routing,
            oper:spy,
            oper:testline,
            oper:unkline,
            oper:wallops,
            oper:xline,
            snomask:nick_changes,
            usermode:servnotice;
        };

        ${concatMapStringsSep "\n" (oper: ''
        operator "${oper.name}" {
        ${concatMapStringsSep "\n" (hostmask: "  user = \"${hostmask}\";") oper.hostmasks}
          password = "${oper.hashedPassword}";
          fingerprint = "${oper.certificateFingerprint}";
          umodes = locops, servnotice, operwall, wallop;
          snomask = "${oper.snomask}";
          flags = encrypted, need_ssl;
          privset = "operator";
        };
        '') (attrValues cfg.opers)}

        ${concatMapStringsSep "\n" (node: ''
        connect "${node.networking.fqdn}" {
          host = "${node.hackint.wireguard.address}";
          send_password = "barkbark!";
          accept_password = "barkbark!";
          hub_mask = "*";
          port = 7000;
          class = "server";
          flags = autoconn, ssl, compressed, topicburst;
        };
        '') (attrValues hubs)}

        ${optionalString cfg.isHub (concatMapStringsSep "\n" (node: ''
        connect "${node.networking.fqdn}" {
          host = "${node.hackint.wireguard.address}";
          send_password = "barkbark!";
          accept_password = "barkbark!";
          hub_mask = "*";
          port = 7000;
          class = "server";
          flags = ssl, compressed, topicburst;
        };
        '') (attrValues leafs))}

        cluster {
          name = "*.hackint.org";
          flags = all;
        };

        service {
          name = "services.hackint.org";
        };

        exempt {
        ${concatMapStringsSep "\n" (host: ''
          ip = "${host}";
        '') cfg.exempts}
        };

        secure {
          ip = "127.0.0.0/8";
          ip = "::1/128";
        };

        channel {
          use_invex = yes;
          use_except = yes;
          use_forward = yes;
          use_knock = yes;
          knock_delay = 5 minutes;
          knock_delay_channel = 1 minute;
          max_chans_per_user = 128;
          max_bans = 100;
          max_bans_large = 500;
          default_split_user_count = 0;
          default_split_server_count = 0;
          no_create_on_split = no;
          no_join_on_split = no;
          burst_topicwho = yes;
          kick_on_split_riding = no;
          only_ascii_channels = no;
          resv_forcepart = yes;
          channel_target_change = yes;
          disable_local_channels = yes;
          autochanmodes = "+Cnt";
          displayed_usercount = 3;
          strip_topic_colors = no;
          opmod_send_statusmsg = yes;
          ip_bans_through_vhost = yes;
        };

        serverhide {
          flatten_links = yes;
          links_delay = 5 minutes;
          hidden = ${if cfg.isHub then "yes" else "no"};
          disable_hidden = no;
        };

        blacklist {
        	host = "rbl.efnetrbl.org";
        	type = ipv4;
          reject_reason = "''${nick}, your IP (''${ip}) is listed in EFnet's RBL. For assistance, see http://efnetrbl.org/?i=''${ip}";

          host = "dnsbl.dronebl.org";
          type = ipv6, ipv4;
          reject_reason = "''${nick}, your IP (''${ip}) is listed in DroneBL. For assistance, see http://dronebl.org/lookup?ip=''${ip}";

          host = "0.0.0.0.dnsel.torproject.org";
          matches = "127.0.0.2";
          reject_reason = "''${nick}, you are connecting from Tor. Please use our Onion service instead, see https://hackint.org/transport/tor";
        };

        alias "NickServ" {
          target = "NickServ";
        };
        alias "ChanServ" {
          target = "ChanServ";
        };
        alias "OperServ" {
          target = "OperServ";
        };
        alias "MemoServ" {
          target = "MemoServ";
        };
        alias "GroupServ" {
          target = "GroupServ";
        };
        alias "HostServ" {
          target = "HostServ";
        };

        alias "NS" {
          target = "NickServ";
        };
        alias "CS" {
          target = "ChanServ";
        };
        alias "OS" {
          target = "OperServ";
        };
        alias "MS" {
          target = "MemoServ";
        };
        alias "GS" {
          target = "GroupServ";
        };
        alias "HS" {
          target = "HostServ";
        };

        general {
          hide_error_messages = opers;
          hide_spoof_ips = no;
          default_umodes = "+i";
          default_operstring = "is an Operator";
          default_adminstring = "is an Administrator";
          servicestring = "is a Network Service";
          sasl_service = "SaslServ";
          disable_fake_channels = no;
          tkline_expire_notices = no;
          default_floodcount = 10;
          failed_oper_notice = yes;
          dots_in_ident = 2;
          min_nonwildcard = 4;
          min_nonwildcard_simple = 3;
          max_accept = 20;
          max_monitor = 100;
          anti_nick_flood = yes;
          max_nick_time = 20 seconds;
          max_nick_changes = 5;
          anti_spam_exit_message_time = 60 minutes;
          ts_warn_delta = 10 seconds;
          ts_max_delta = 2 minutes;
          client_exit = yes;
          collision_fnc = yes;
          resv_fnc = yes;
          global_snotices = yes;
          dline_with_reason = yes;
          kline_with_reason = yes;
          hide_tkdline_duration = no;
          kline_reason = "Connection closed";
          identify_service = "NickServ@services.hackint.org";
          identify_command = "IDENTIFY";
          non_redundant_klines = yes;
          warn_no_nline = yes;
          use_propagated_bans = yes;
          stats_e_disabled = yes;
          stats_c_oper_only = yes;
          stats_y_oper_only = yes;
          stats_o_oper_only = yes;
          stats_P_oper_only = yes;
          stats_i_oper_only = yes;
          stats_k_oper_only = yes;
          stats_l_oper_only = self;
          map_oper_only = no;
          operspy_admin_only = no;
          operspy_dont_care_user_info = no;
          caller_id_wait = 1 minute;
          pace_wait_simple = 1 second;
          pace_wait = 10 seconds;
          listfake_wait = 0 seconds;
          short_motd = no;
          ping_cookie = yes;
          connect_timeout = 30 seconds;
          default_ident_timeout = 5;
          disable_auth = no;
          no_oper_flood = yes;
          max_targets = 4;
          post_registration_delay = 2 seconds;
          use_whois_actually = yes;
          oper_only_umodes = operwall, locops, servnotice;
          oper_umodes = locops, servnotice, operwall, wallop;
          oper_snomask = "+fsxZ";
          #compression_level = 6;
          burst_away = yes;
          nick_delay = 0 seconds;
          reject_ban_time = 1 minute;
          reject_after_count = 3;
          reject_duration = 5 minutes;
          throttle_duration = 60;
          throttle_count = 4;
          client_flood_max_lines = 20;
          client_flood_burst_rate = 40;
          client_flood_burst_max = 5;
          client_flood_message_time = 1;
          client_flood_message_num = 2;
          max_ratelimit_tokens = 30;
          away_interval = 30;
          certfp_method = spki_sha256;
          hide_opers_in_whois = no;
          tls_ciphers_oper_only = no;
          #hidden_caps = "userhost-in-names";
          oper_secure_only = yes;
        };

        modules {
          path = "${pkgs.solanum.out}/modules";
          path = "${pkgs.solanum.out}/modules/autoload";
          /* module: the name of a module to load on startup/rehash */
          #module = "some_module.so";
        };
      '';
    };

    environment.systemPackages = [ pkgs.solanum ];
  };
}

