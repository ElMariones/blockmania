# Third-party components and provenance

| Component | Path | Version | License | Use | Ships in release? |
|---|---|---|---|---|---|
| Godot Engine | (external) | 4.7.2 stable | MIT | Engine | Yes (runtime) |
| Godot AI editor plugin | `addons/godot_ai/` | 4.2.1 | MIT (`addons/godot_ai/LICENSE`) | Development tooling: MCP bridge between AI assistants and the editor | **No.** Its `_mcp_game_helper` autoload must be removed or gated before release exports (TASKS.md M2). |
| Godot default icon | `icon.svg` | Godot template | MIT (Godot) | Placeholder project icon | No, to be replaced by original BLOCKMANIA icon |

No other external code, fonts, images, or audio are included. All in-game visuals are drawn procedurally by project code (`game/presentation/block_painter.gd`, `game/presentation/backdrop.gd`) and use Godot's built-in default font.
