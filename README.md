# Skills

Agent skills I use in my work. Each skill is a folder with a `SKILL.md`, readable by Claude Code
and other agents that support agent skills.

| Skill | What it does |
|---|---|
| [deangularize](skills/deangularize/SKILL.md) | Migrates the AngularJS 1.x admin SPA of a Rails app to server-rendered views with Unpoly, React islands for heavyweight widgets and Bootstrap 5 at the end, area by area, with the feature specs as the specification. |

## Install

```bash
npx skills add begerdom/skills --skill deangularize
```

Or copy `skills/deangularize` to `~/.claude/skills/deangularize`. The skill calls its scripts
from `~/.claude/skills/deangularize/scripts/`.

## License

MIT, see [LICENSE](LICENSE).
