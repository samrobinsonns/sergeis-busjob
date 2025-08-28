# 🚌 Sergeis Bus Driving System

A comprehensive FiveM bus driving script with an integrated iPad-styled dashboard, route management, and passenger system.

## ✨ Features

### 🎯 **Dashboard System**
- **iPad-Styled UI** - Modern, responsive dashboard with realistic device aesthetics
- **Three Main Tabs**:
  - **Dashboard** - Player statistics, XP progress, and performance metrics
  - **Routes** - Available routes with detailed information and start buttons
  - **Leaderboard** - Weekly, monthly, and global rankings

### 🚗 **Route Management**
- **Config-Driven Routes** - All routes defined in `config.lua`
- **Automatic Passenger Loading** - Passengers spawn and load automatically at stops
- **Real-Time Progress Tracking** - GPS waypoints and bus markers
- **Anti-Exploit Protection** - Rate limiting and validation

### 📊 **Player Progression**
- **XP System** - Earn experience for completing routes and loading passengers
- **Leveling System** - 10 configurable levels with titles and payment bonuses
- **Statistics Tracking** - Distance, jobs completed, total earnings
- **Database Integration** - MySQL storage for persistent player data

### 🎮 **Gameplay Features**
- **Target System** - Use `qb-target` or `ox_target` to open dashboard
- **Bus Spawning** - Automatic bus creation with player identification
- **Passenger System** - Realistic passenger spawning and loading
- **Payment System** - Base payment + passenger bonuses + level multipliers

## 🚀 Installation

### 1. **Database Setup**
```sql
-- Import the SQL file to create required tables
mysql -u username -p database_name < sql/bus_jobs.sql
```

### 2. **Resource Installation**
```bash
# Copy the resource to your server's resources folder
cp -r sergeis-bus /path/to/your/server/resources/

# Add to server.cfg
ensure sergeis-bus
```

### 3. **Dependencies**
- **QBCore Framework** - Required for player management
- **qb-target** or **ox_target** - For interactive zones
- **MySQL** - For database operations

## ⚙️ Configuration

### **Depot Location**
```lua
Config.Depot = {
    x = 456.0,
    y = -1025.0,
    z = 28.0,
    heading = 90.0
}
```

### **Routes**
```lua
Config.Routes = {
    {
        name = "Downtown Express",
        stops = {
            {x = 200.0, y = -800.0, z = 30.0, name = "Downtown Central"},
            -- Add more stops...
        },
        basePayment = 150,
        baseXP = 50,
        distanceMultiplier = 0.1
    }
}
```

### **Leveling System**
```lua
Config.Leveling = {
    levels = {
        [1] = {xp = 0, title = "Rookie Driver", bonus = 1.0},
        [2] = {xp = 100, title = "Novice Driver", bonus = 1.05},
        -- Add more levels...
    }
}
```

## 🎮 Usage

### **Starting a Job**
1. **Go to Bus Depot** - Travel to the configured depot location
2. **Open Dashboard** - Use the target system to open the dashboard
3. **Select Route** - Choose from available routes in the Routes tab
4. **Start Driving** - Bus spawns automatically with GPS waypoints
5. **Collect Passengers** - Stop at each bus stop to load passengers
6. **Complete Route** - Return to depot for payment and XP

### **Dashboard Navigation**
- **Dashboard Tab** - View your statistics and progress
- **Routes Tab** - Browse and start available routes
- **Leaderboard Tab** - Check rankings and compare with other players

### **Commands**
- `/endbus` - End current route early
- `/bushelp` - Show help information
- `/busstats` - Display your statistics
- `/givebusmoney [id] [amount]` - Admin command to give money

## 🔧 Customization

### **Adding New Routes**
1. Edit `config.lua`
2. Add new route configuration
3. Define stops with coordinates and names
4. Set payment and XP values

### **Modifying UI**
- **HTML**: Edit `html/index.html` for structure
- **CSS**: Modify `html/style.css` for styling
- **JavaScript**: Update `html/script.js` for functionality

### **Database Schema**
The system uses these main tables:
- `bus_jobs` - Player statistics and progression
- `bus_job_history` - Individual job records
- `bus_leaderboard` - Weekly/monthly rankings
- `bus_levels` - Level configuration and bonuses

## 🧪 Testing

### **Browser Testing**
Open `html/test-dashboard.html` to test the UI with mock data:
- Test dashboard functionality
- Verify iPad styling
- Check responsive design
- Simulate route selection

### **FiveM Testing**
1. Start your server
2. Ensure the resource loads without errors
3. Test depot targeting
4. Verify dashboard functionality
5. Test route completion

## 🐛 Troubleshooting

### **Common Issues**
- **Dashboard not opening**: Check target system configuration
- **Routes not starting**: Verify anti-exploit settings
- **Database errors**: Ensure MySQL tables are created
- **UI not displaying**: Check file paths in fxmanifest.lua

### **Debug Mode**
Enable debug mode in `config.lua`:
```lua
Config.Debug = {
    enabled = true,
    logLevel = 'debug'
}
```

## 📝 API Reference

### **Client Events**
- `bus:openDashboard` - Opens the dashboard
- `bus:updatePlayerStats` - Updates player statistics
- `bus:updateRoutes` - Updates available routes
- `bus:updateLeaderboard` - Updates leaderboard data

### **Server Events**
- `bus:getPlayerStats` - Requests player statistics
- `bus:checkRouteStart` - Validates route start
- `bus:completeRoute` - Processes route completion

### **NUI Callbacks**
- `closeDashboard` - Closes the dashboard
- `startRoute` - Starts a selected route

## 🤝 Support

### **Requirements**
- FiveM Server
- QBCore Framework
- MySQL Database
- qb-target or ox_target

### **Version Compatibility**
- **FiveM**: Latest stable version
- **QBCore**: v2.0+
- **MySQL**: 5.7+

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Credits

- **Framework**: QBCore
- **Target System**: qb-target / ox_target
- **UI Design**: iPad-styled dashboard interface
- **Database**: MySQL with stored procedures

---

**Happy Driving! 🚌✨**
