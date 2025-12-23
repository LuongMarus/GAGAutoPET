# Marus Auto Farm - Grow A Garden

**GitHub Repository**: https://github.com/LuongMarus/GAGAutoPET.git

## Cấu trúc project

```
gag/
├── main.lua              # Entry point chính
├── modules/
│   ├── config.lua        # Quản lý cấu hình
│   ├── webhook.lua       # Discord webhook notifications
│   ├── core.lua          # Logic farm chính
│   └── ui.lua            # Giao diện Fluent UI
└── README.md             # Documentation
```

## Tính năng

- Auto farm pet đến target age
- UUID-based tracking (không bị ảnh hưởng bởi mutation)
- Tự động phát hiện pet mới
- Mutation detection & filtering
- Discord webhook notifications
- Mobile support (draggable toggle button)
- Modular structure (dễ maintain & extend)

## Cách sử dụng

### Load từ GitHub:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/LuongMarus/GAGAutoPET/main/main.lua"))()
```

### Load local (testing):
```lua
loadstring(game:HttpGet("https://your-url.com/main.lua"))()
```

### Module structure:
Mỗi module là một file Lua độc lập với chức năng riêng:

**config.lua**
- Quản lý cấu hình toàn cục
- Initialize settings
- Update/Get settings

**webhook.lua**
- SendPetMaxLevel() - Thông báo pet đạt age
- SendMutationAchieved() - Thông báo pet đạt mutation

**core.lua**
- IsMutation() / IsExcludedMutation()
- ScanAndBuildTargetList()
- ScanAndUpdateStorage()
- ManageGarden()
- PlantPets()

**ui.lua**
- Initialize() - Tạo UI window
- BuildInfoTab() / BuildFarmTab() / BuildMiscTab() / BuildSettingsTab()
- UpdateMiscPetList()
- Notify()

## Workflow

1. **Nhập tên pet** (ví dụ: "Phoenix")
2. **Auto scan** tất cả pet trong Backpack/Character/Garden
3. **Lưu UUID** vào TargetUUIDs
4. **Bật Auto Farm** → Script tự động:
   - Plant pet chưa đạt Age
   - Harvest pet đã đạt Age
   - Phát hiện pet mới (sau mutation/mua/nở)
   - Loại trừ mutation (Mega/Rainbow/Ascended/Nightmare)

## Settings

- **Target Age**: Tuổi thu hoạch (mặc định: 50)
- **Max Slots**: Tổng slot vườn (mặc định: 6)
- **Farm Limit**: Giới hạn farm (mặc định: 6)
- **Exclude Mutation**: Loại trừ pet mutation đặc biệt (mặc định: ON)

## Webhooks

Script gửi 2 loại notification:
- **PET MAX LEVEL** (màu xanh) - Pet đạt age target
- **MUTATION ACHIEVED** (màu vàng) - Pet đạt mutation target

## Mobile Support

Nút toggle "M" có thể:
- Kéo di chuyển
- Click để ẩn/hiện UI
- Không mất khi respawn

## Development
1. Chọn module phù hợp (core/ui/webhook/config)
2. Thêm function vào module
3. Export function qua `return ModuleName`
4. Require và sử dụng trong main.lua

## Version History

**v1.2** - Module Structure
- Tách thành 4 modules độc lập
- Cấu trúc code chuẩn Lua
- Dễ maintain & scale

**v1.1** - UUID System
- UUID-based tracking
- Auto detect new pets
- Mutation filtering

**v1.0** - Initial Release
- Basic auto farm
- Fluent UI
- Webhook support

---
Made by **Marus** | Ver 1.2
