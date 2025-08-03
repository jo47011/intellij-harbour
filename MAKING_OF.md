# Making of my Harbour Plugin for IntelliJ/PyCharm

Ever since I started this project it was intentionally a hands-**off** project.  
Actually it turned out to be my 1st big vibe-coding (*) project.  
For me, it was a great journey to learn how to instruct and how to monitor my AI agents to do what I want.
I have not coded a single line of code in this project. This was often a challenge and cumbersome as the AI
tends to be lazy or at least looking for the shortest possible way to achieve a task. See section key learnings (*)
for details. But it is so impressive how quick one can achieve very complicated tasks that this will change
our programmers daily live forever.

## Starting Out (Late 2024)

I began working on the Harbour plugin project at the end of 2024, initially using **O1 Pro**. At the time, it was a
solid approach and served me well. However, everything changed when **Cloud Sonnet 3.7** was released — I immediately
switched over, and it turned out to be significantly better for programming tasks.

That said, both tools were limited to UI-only experiences, whether on desktop or web. This led to a lot of copy-pasting,
trial and error, pasting stack traces, and dealing with other similar inefficiencies.

Still, with enough persistence, I managed to get the plugin itself running — albeit without a debugger. Setting up the
debugger in this environment turned out to be too complex and error-prone.

## Enter Code w/ Claude (Early 2025)

In early 2025 — around March or April — **Claude Code** (*) was introduced. This was a game-changer. It’s an AI agent
that can be installed locally. I opted to run it in a **Docker environment**, ensuring it operates in isolation without
impacting my main system or data.

This setup finally gave me the flexibility, safety, and integration I was missing before — paving the way for real
progress.

## Docker environment

Why a docker environment? Well I want to be sure that my AI agents, that I often have working over night by their own,
cannot do any harm to my system. So I set up a `secured/restricted` environment and just mount in the project
directories that Claude should work on. Claude has not root acces in that container. So I install the commands for him
that I allow him to use. Otherwise, he would freely install whatever package he might need, which is not what I want.
Sometimes the AI seems overmotivated and changes parts of the projects which you didn't ask for. Like this I can be
sure Claude will not change any other project on my system.

Whoever thinks this is over the top should read
[Agentic Misalignment](https://www.anthropic.com/research/agentic-misalignment). There are multiple tests where e.g.
Claude would call the police by phone (if enabled) or send an email to some authorities to inform them about some
potential criminal activities. So you better be aware of what you allow your AI agents.

My Claude can talk to me, e.g. when he is finished w/ a task, using [piper-tts](https://github.com/rhasspy/piper).
He can also send me an email for the same purpose when I am away from my desc. But I made sure, that he can only
send emails to me and to no-one else.... Hopefully :scream:

I will publish my `secure` docker environment sometime later in another FOSS package.

## Key learnings

There is a lot of great tutorials on youtube and on the internet, so I keep this section short as otherwise I
could write endless pages.

1. Invest some time in setting up your environment it is worth it in the long run.

   This also includes [customizing your AI setup](https://www.anthropic.com/engineering/claude-code-best-practices).
   Define clear rules in your Claude.md files on all levels: globally, per user or project based.

2. Work in a environment where you can roll back changes made, e.g. using git.

   This is crucial since sometimes the AI is still hallucinating or just didn't understand what you meant and
   screws up your previously working version.

3. Be precise and clear in your instructions and expectations.

   This is one of the keys. Investing a few more minutes in your prompt will avoid some endless loops going back
   and forth w/ your AI. BTW I never typed into the Claude prompt directly but edited a file using my standard
   editor and then I would tell Claude just to read this file. Disadvantages are the when resuming an old session
   you will not see a reasonable description. But since I usually only re-used the last one or two sessions I
   preferred that approach.

4. Verify the results and review the generated code

   To be honest I did not read every single of code, maybe you should  :smirk:
   If the AI can it chooses the shortest way to achieve the goals. Here are two examples:

    - Hardcoding exceptions or alike

      Quite often I found commands like this in my code, which is designed as a generic product and Claude knew it:
      ```
      if (workingDirectory.equals("/home/myname/myproject/foobar")) {...}
      ```
    - Too broad instructions lead to wrong results.

      I told Claude to write some tests for all java files and if possible to reach for a high coverage.
      As always Claude was very quick and I was impressed by the results until I looked into the code. 
      He mainly wrote a test for each file just counting the number of methods. Nothing else,
      no logic, mindlessly just covering all files.

## Coding Details (as of 2025-08-03)

Total Lines of Code: 34,621 generated by AI only.

I'm very sure this project is far from being perfect and a lot of code snippets or functions would need a major
polishing. But hey, who cares, it is working :smile:

Breakdown by File Type:

- Java Source Code: 29,079 lines (135 files)
- Generated Java Code: 1,290 lines (1 file - _HarbourLexer.java)
- Harbour Code: 4,485 lines (9 files - debug handlers, error monitors)
- XML Files: 2,645 lines (103 files - plugin config, project settings)
- Gradle Build: 112 lines