enum SupportedProtocols { NIL, MYSQL }

class BreadDatabaseInfo {
  final SupportedProtocols protocol;
  final String? username;
  final String? password;
  final String? host;
  final String? port;
  final String? databaseName;

  BreadDatabaseInfo({
    required this.protocol,
    this.username,
    this.password,
    this.host,
    this.port,
    this.databaseName,
  });
}

class DbUriValidation {
  final uriParserRegex = RegExp(
      r'^(?<protocol>[a-zA-Z0-9]+):(\/{2})?(?<auth>(?<username>\w+)(:(?<password>[\w\<\>\*\!\?\.\,\{\}\[\]\=\+\-\&\^\%\$\#\`\~\;\:\"]+))?@)?((?<host>[\w\.\-]+)(\:(?<port>[0-9]{2,6}))?)(\/(?<database_name>[\w]+))?$');

  bool validate(String databaseUri) {
    return uriParserRegex.hasMatch(databaseUri);
  }

  BreadDatabaseInfo parse(String databaseUri) {
    final uriParts = uriParserRegex.firstMatch(databaseUri);

    final uriProtocol = uriParts?.namedGroup('protocol');
    SupportedProtocols protocol;

    switch (uriProtocol?.toLowerCase()) {
      case 'mysql':
        protocol = SupportedProtocols.MYSQL;
        break;
      default:
        protocol = SupportedProtocols.NIL;
    }

    return BreadDatabaseInfo(
      protocol: protocol,
      username: uriParts?.namedGroup('username'),
      password: uriParts?.namedGroup('password'),
      host: uriParts?.namedGroup('host'),
      port: uriParts?.namedGroup('port'),
      databaseName: uriParts?.namedGroup('database_name'),
    );
  }
}
