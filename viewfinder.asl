state("Viewfinder_Demo", "demo1") {}

state("Viewfinder_Demo", "demo2") {
    bool isLoading: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x20;
    bool isTransition: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x21;
    bool isMainMenu: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x22;
    int levelID: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x24;
    int isRunning: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x28;
}

startup {
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Viewfinder Demo";
    vars.Helper.LoadSceneManager = true;
    vars.Helper.StartFileLogger("ViewfinderASL.log");

    settings.Add("split_exit", true, "Split on level end");
    settings.Add("12", true, "Level 1", "split_exit");
    settings.Add("8", true, "Level 2", "split_exit");
    settings.Add("13", true, "Level 3", "split_exit");
    settings.Add("9", true, "Level 4", "split_exit");
    settings.Add("6", true, "Level 5", "split_exit");
    settings.Add("10", true, "Level 6", "split_exit");
    settings.Add("11", true, "Level 7", "split_exit");

    vars.splitsDone = new HashSet<int>();

    vars.levelNameMap = new Dictionary<string, string>() {
        {"1:1.1", "12"},
        {"1:1.2", "12"},
        {"1:1.3", "12"},
        {"1:2.1", "12"},
        {"1:2.3", "12"},
        {"1:2.4", "12"},
        {"3:2.1", "12"},
    };
}

init
{
    if (modules.First().ModuleMemorySize == 675840) {
        version = "demo2";
    } else {
        version = "demo1";
    }
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono => {
        if (version == "demo1") {
            vars.Helper["loadState"] =
                mono["ViewfinderAssembly", "AdditiveSceneManager"]
                .Make<int>("instance", 0x30);

            vars.Helper["transitionInterpolator"] =
                mono["ViewfinderAssembly", "TransitionImageEffect", 1]
                .Make<float>("_instance", 0x88);

            vars.Helper["transitionState"] =
                mono["ViewfinderAssembly", "TransitionImageEffect", 1]
                .Make<int>("_instance", 0x90);

            // PersistentGameController._instance.currentLevel.LevelID
            vars.Helper["Level"] = 
                mono["ViewfinderAssembly", "PersistentGameController", 1]
                .MakeString("_instance", 0x18, 0x80);

            // GameStateManager.instance.gameStates;
            vars.Helper["gameStates"] =
                mono["ViewfinderAssembly", "GameStateManager"]
                .MakeList<ValueTuple<long, long>>("instance", 0x18);
        }
        return true;
    });
}

update
{
    if(version == "demo1") {
        current.gameState = current.gameStates[current.gameStates.Count - 1].Item1;
    }
}

onStart {
    vars.splitsDone.Clear();
}

start {
    if (version == "demo1") {
        return current.Level == "1:1.1" && current.loadState == 0 && old.loadState == 4;
    } else {
        return !current.isLoading && old.isLoading && current.levelID == 12;
    }
}

reset
{
    if (version == "demo2") {
        return current.isMainMenu && !old.isMainMenu;
    }   
}

split {
    if (version == "demo1") {
        if (current.gameState == 3 && old.gameState != 3) {
            return true;
        }

        if (current.Level != old.Level) {
            string level = vars.levelNamesMap[old.Level];
            if (settings[level] && vars.splitsDone.Add(level)) {
                return true;
            }
        }
    } else {
        if (current.isRunning == 2 && old.isRunning == 1) {
            return true;
        }

        if (current.levelID != old.levelID) {
            return settings[old.levelID.ToString()] && vars.splitsDone.Add(old.levelID);
        }
    }
}

isLoading {
    if (version == "demo1") {
        if (current.transitionState == 2) {
            return true;
        }
        if (current.transitionState == 3) {
            return current.transitionInterpolator != 1f &&
                current.transitionInterpolator == old.transitionInterpolator &&
                current.gameState != 2;
        }
    } else {
        return current.isTransition && current.isLoading;
    }
}