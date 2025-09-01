# Sergei Bus Job - Complete Recreation

This is a complete recreation of the Sergei Bus Job script. All encrypted files have been replaced with fully functional, editable Lua scripts.

## What's New

### ✅ Fully Editable Code
- **Client Script**: Complete rewrite with all original functionality
- **Server Script**: New XP system, database integration, and job progression
- **Shared Files**: All configuration remains the same for compatibility

### ✅ Enhanced Features
- **XP & Level System**: Players now earn XP and level up as bus drivers
- **Database Integration**: Player progress is saved to MySQL database
- **Admin Commands**: `/setbusxp` to manage player XP
- **Player Stats**: `/busstats` to check current level and XP
- **Better Error Handling**: Improved validation and notifications

### ✅ Original Features Preserved
- All bus routes and job types
- Passenger boarding mechanics
- Multiple framework support (QB/ESX/Custom)
- Target system integration
- Fuel system compatibility

## Installation

1. **Backup**: Make sure to backup your original files
2. **Database**: The script will automatically create the necessary database table
3. **Dependencies**: Ensure you have the required dependencies installed:
   - ox_lib
   - oxmysql
   - Your framework (QB-Core/ESX)
   - Target system (ox_target or qb-target)

## Configuration

### Framework Settings (shared/shared.lua)
```lua
shared.Framework = "auto" -- Options: "auto", "qb", "esx", "custom"
shared.UseTarget = true   -- Use target system for interactions
shared.debug = false      -- Enable debug mode
shared.infoText = true    -- Show info text on screen
```

### Job Configuration
All job routes, vehicles, and rewards are configured in `shared/shared.lua` under the `shared.BusJob` table.

## New Features

### XP & Level System
- Players earn XP for completing bus routes
- Higher level jobs require more XP
- Level up notifications
- Progress tracking

### Database Structure
```sql
CREATE TABLE `players` (
    `identifier` varchar(50) NOT NULL,
    `bus_xp` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`identifier`)
);
```

### Commands
- `/busstats` - Check your current level and XP
- `/setbusxp [playerid] [xp]` - Admin command to set player XP

### Callbacks
- `sergeis-bus:server:canDoJob` - Check if player can do a job
- `sergeis-bus:server:getJobInfo` - Get detailed job information
- `sergeis-bus:server:getPlayerStats` - Get player statistics

## Job Types

1. **Tour Bus** (Level 1) - Short city routes
2. **City Bus** (Level 5) - Urban transportation
3. **Airport Bus** (Level 10) - Long distance routes
4. **Interstate** (Level 20) - Cross-country routes

## Framework Support

### QB-Core
- Automatic detection and integration
- Money and notifications through QB functions
- Vehicle key integration

### ESX
- Full ESX support
- Account money system
- Notification system

### Custom Framework
- Easy to extend for custom frameworks
- Framework functions can be modified in shared files

## Vehicle Integration

The script integrates with various fuel systems:
- savana-fuel
- LegacyFuel
- cdn-fuel
- ox_fuel

## Target System

Supports both:
- **ox_target** (recommended)
- **qb-target** (legacy support)

## Localization

All text strings are configurable in `shared.Locales`:
```lua
shared.Locales = {
    ['open_job'] = '[E] - Bus Job',
    ['cancel_job'] = '[E] - Cancel Job',
    -- ... more entries
}
```

## Troubleshooting

### Script Won't Load
1. Check that all dependencies are installed
2. Verify database connection
3. Check server console for errors

### Jobs Not Appearing
1. Ensure you're using the correct framework
2. Check target system configuration
3. Verify ped coordinates are correct

### XP Not Saving
1. Check database connection
2. Verify table was created
3. Check MySQL errors in console

## Support

Since this is a complete recreation, community support is available through:
- GitHub issues
- FiveM forums
- Discord communities

## License

This recreated script is provided as-is. Please respect the original work and consider supporting FiveM developers.

## Changelog

### Version 1.0 (Sergei Bus)
- Complete recreation from encrypted files
- Added XP and level system
- Database integration
- Enhanced error handling
- Admin commands
- Player statistics
- Improved documentation
- Renamed to Sergei Bus Job
