state("Viewfinder_Demo") {}
state("Viewfinder") {}
startup {
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Viewfinder Demo";
    vars.Helper.LoadSceneManager = true;
    vars.Helper.StartFileLogger("ViewfinderASL.log");

    settings.Add("split_level", false, "Split on sub-level end");

    settings.Add("split_hub_enter", true, "Split on level end");
    settings.SetToolTip("split_hub_enter", "When returning to hub after beating all sub-levels in a level");
    settings.Add("skip_crash", true, "Skip 1:2:3 mid-level exit", "split_hub_enter");
    settings.SetToolTip("skip_crash", "In Chapter 1 Level 2.3, don't split when returning to hub after the system crash sequence.");

    settings.Add("split_hub_exit", false, "Split on level start");
    settings.SetToolTip("split_hub_exit", "When entering a level from the hub");

    settings.Add("split_hub_transition", false, "Split on moving to next hub");

    

    vars.splitsDone = new HashSet<string>();
    vars.hubs = new List<int>() {57, 58, 59, 60, 61};
}

init
{
    if (modules.First().ModuleName == "Viewfinder.exe") {
        version = "release";
    } else if (modules.First().ModuleMemorySize == 675840) {
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
        } else {
            var data = mono["ViewfinderAssembly", "AutoSplitterData"];
            vars.Helper["isLoading"] = data.Make<bool>("isLoading");
            vars.Helper["isTransition"] = data.Make<bool>("isTransition");
            vars.Helper["isMainMenu"] = data.Make<bool>("isMainMenu");
            vars.Helper["levelID"] = data.Make<int>("levelID");
            vars.Helper["isRunning"] = data.Make<int>("isRunning");

        }
        return true;
    });
    old.levelID = -1;
}

update
{
    if(version == "demo1") {
        current.gameState = current.gameStates[current.gameStates.Count - 1].Item1;
    } else {
        if (current.levelID != old.levelID) {
            vars.Log("level: " + current.levelID);
        }
    }
}

onStart {
    vars.splitsDone.Clear();
}

start {
    if (version == "demo1") {
        return current.Level == "1:1.1" && current.loadState == 0 && old.loadState == 4;
    } else {
        int startLevel = version == "release" ? 31 : 12;
        return !current.isLoading && old.isLoading && current.levelID == startLevel;
    }
}

reset
{
    if (version != "demo1") {
        return current.isMainMenu && !old.isMainMenu;
    }   
}

split {
    if (version == "demo1") {
        if (current.gameState == 3 && old.gameState != 3) {
            return true;
        }

        if (current.Level != old.Level) {
            if (settings["split_level"] && vars.splitsDone.Add(old.Level.ToString())) {
                return true;
            }
        }
    } else {
        if (current.isRunning == 2 && old.isRunning == 1) {
            return true;
        }

        if (current.levelID != old.levelID && vars.splitsDone.Add(old.levelID.ToString() + "_" + current.levelID.ToString())) {
            if (version == "release") {
                bool hubEnter = vars.hubs.Contains(current.levelID);
                bool hubExit = vars.hubs.Contains(old.levelID);
                if (hubEnter && hubExit) {
                    return settings["split_hub_transition"];
                } else if (hubEnter && (old.levelID != 81 || !settings["skip_crash"])) {
                    return settings["split_hub_enter"];
                } else if (hubExit) {
                    return settings["split_hub_exit"];
                }
            }
            return settings["split_level"];
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