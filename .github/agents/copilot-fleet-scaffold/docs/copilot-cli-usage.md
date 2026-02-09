# Как да ползваш тази структура (Copilot CLI)

## 1) Сложи файловете в root на проекта
Тези директории трябва да съществуват:
- `.github/agents/`  (агентите)
- `.github/instructions/` (path-specific инструкции)
- `.github/copilot-instructions.md` (repo-wide инструкции)
- `AGENTS.md` (агентни правила)

## 2) Провери, че Copilot CLI вижда агентите
В интерактивен режим:
- стартирай `copilot`
- изпълни `/agent` за списък с наличните агенти

Copilot CLI поддържа repo-level агенти в `.github/agents`. citeturn0search0

## 3) Препоръчан поток (“мини fleet”)
1) Избери **Fleet Lead** и опиши задачата.
2) Fleet Lead ще поиска план → при нужда избери **Architect**.
3) За патерни/контекст → **Researcher**.
4) За реални промени → **Implementer**.
5) За тестове → **Tester**.
6) За ревю → **Reviewer**.
7) За сигурност/зависимости → **Security**.
8) За README/usage → **Docs**.

## 4) Къде Copilot CLI зарежда агенти
- `.github/agents` (repo-level)
- `~/.copilot/agents` (user-level)
- `.github-private/agents` (org/enterprise-level)

citeturn0search0turn1search0
