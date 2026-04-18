# etl-xpsave

[ET: Legacy](https://github.com/etlegacy/etlegacy) server script for xpsave.

### Description

- xp is saved as sqlite3 file which is created in ./legacy folder next to the etl-xpsave lua script
- xp is automatically saved each minute for all players (including bots)
- xp is automatically loaded when player joins the server
- xp is automacially saved when user disconnects the server

### Installation

1. Download etl-xpsave and put it in the ./legacy folder which is inside the main [ET: Legacy](https://github.com/etlegacy/etlegacy) directory.
2. Update lua_modules variable in your server configuration file e.g.

    /set lua_modules "etl-xpsave.lua"

3. Start your server and enjoy the game :)

### Change to the original repo
- replaced dkjson with et legacy's built-in sqlite capability due to dkjson incompatability with latest lua
- removed console commands

### License [MIT](LICENSE.md)
