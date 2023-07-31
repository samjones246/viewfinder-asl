state("Viewfinder") {}
startup {
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Viewfinder";
    vars.Helper.LoadSceneManager = true;
    vars.Helper.StartFileLogger("ViewfinderASL.log");

    settings.Add("split_level", false, "Split on sub-level end");

    settings.Add("split_hub_enter", true, "Split on level end");
    settings.SetToolTip("split_hub_enter", "When returning to hub after beating all sub-levels in a level");

    settings.Add("split_hub_exit", false, "Split on level start");
    settings.SetToolTip("split_hub_exit", "When entering a level from the hub");

    settings.Add("split_hub_transition", false, "Split on moving to next hub");

    vars.splitsDone = new HashSet<string>();
    vars.hubs = new List<int>() {57, 58, 59, 60, 61};
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono => {
        var data = mono["ViewfinderAssembly", "AutoSplitterData"];
        vars.Helper["isLoading"] = data.Make<bool>("isLoading");
        vars.Helper["isMainMenu"] = data.Make<bool>("isMainMenu");
        vars.Helper["levelID"] = data.Make<int>("levelID");
        vars.Helper["isRunning"] = data.Make<int>("isRunning");
        vars.Helper["isRidingTrain"] = data.Make<bool>("isRidingTrain");
        return true;
    });
    old.levelID = -1;
    old.journeyStart = "";
}

update
{
    if (current.levelID != old.levelID) {
        vars.Log("levelID: " + current.levelID);
    }
    if (current.isLoading != old.isLoading) {
        vars.Log("isLoading: " + current.isLoading);
    }
}

onStart {
    vars.splitsDone.Clear();
    vars.Log("-- RUN START --");
}

start {
    return !current.isLoading && old.isLoading && current.levelID == 31;
}

onReset
{
    vars.Log("-- RUN RESET --");
}

split {
    if (current.isRunning == 2 && old.isRunning == 1) {
        vars.Log("Split: Run End");
        return true;
    }

    if (
        current.levelID != old.levelID &&
        vars.splitsDone.Add(old.levelID.ToString() + "_" + current.levelID.ToString())
    ) {
        bool hubEnter = vars.hubs.Contains(current.levelID);
        bool hubExit = vars.hubs.Contains(old.levelID);
        if (hubEnter && hubExit) {
            // Do nothing. TODO: Add a setting for this after the patch comes out.
        } else if (hubEnter) {
            if (old.levelID != 81 && settings["split_hub_enter"]) {
                vars.Log("Split: Level End");
                return true;
            }
        } else if (hubExit) {
            if (settings["split_hub_exit"]) {
                vars.Log("Split: Level Enter");
                return true;
            }
        }
        
        if (!hubExit && settings["split_level"]) {
            vars.Log("Split: Sub-level End");
            return true;
        }
    }

    if (
        current.isRidingTrain && !old.isRidingTrain && 
        vars.splitsDone.Add(current.levelID + "train") &&
        settings["split_hub_transition"]
    ) {
        vars.Log("Split: Hub Transition");
        return true;
    }
}

isLoading {
    return current.isLoading;
}