state("Viewfinder") {
    bool isLoading : "GameAssembly.dll", 0x3D12B60, 0xB8, 0x20;
    bool isRidingTrain : "GameAssembly.dll", 0x3D12B60, 0xB8, 0x22;
    int levelID : "GameAssembly.dll", 0x3D12B60, 0xB8, 0x24;
    int isRunning : "GameAssembly.dll", 0x3D12B60, 0xB8, 0x2C;
}
startup {
    settings.Add("split_level", false, "Split on sub-level end");

    settings.Add("split_hub_enter", true, "Split on level end");
    settings.SetToolTip("split_hub_enter", "When returning to hub after beating all sub-levels in a level");

    settings.Add("split_hub_exit", false, "Split on level start");
    settings.SetToolTip("split_hub_exit", "When entering a level from the hub");

    settings.Add("split_hub_transition", false, "Split on moving to next hub");

    settings.Add("il_mode", false, "Individual Level Mode");

    vars.splitsDone = new HashSet<string>();
    vars.hubs = new List<int>() {57, 58, 59, 60, 61, 62};
}

init
{
    old.levelID = -1;
    old.journeyStart = "";
    vars.prevLevel = -1;
}

update
{
    if (current.levelID != old.levelID) {
        vars.prevLevel = old.levelID;
        print("levelID: " + current.levelID);
        print("prevLevel: " + vars.prevLevel);
    }
    if (current.isLoading != old.isLoading) {
        print("isLoading: " + current.isLoading);
    }
}

onStart {
    vars.splitsDone.Clear();
    print("-- RUN START --");
}

start {
    if (!current.isLoading && old.isLoading) {
        if (settings["il_mode"]) {
            return vars.hubs.Contains(vars.prevLevel) && !vars.hubs.Contains(current.levelID);
        } else {
            return current.levelID == 31;
        }
    }
    return !current.isLoading && old.isLoading && 
        (current.levelID == 31 || settings["il_start"]);
}

onReset
{
    print("-- RUN RESET --");
}

split {
    if (current.isRunning == 2 && old.isRunning == 1) {
        print("Split: Run End");
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
                print("Split: Level End");
                return true;
            }
        } else if (hubExit) {
            if (settings["split_hub_exit"]) {
                print("Split: Level Enter");
                return true;
            }
        }
        
        if (!hubExit && settings["split_level"]) {
            print("Split: Sub-level End");
            return true;
        }
    }

    if (
        current.isRidingTrain && !old.isRidingTrain && 
        vars.splitsDone.Add(current.levelID + "train") &&
        settings["split_hub_transition"]
    ) {
        print("Split: Hub Transition");
        return true;
    }
}

isLoading {
    return current.isLoading;
}