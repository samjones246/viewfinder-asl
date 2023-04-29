state("Viewfinder_Demo") {}

startup {
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Viewfinder Demo";
    vars.Helper.LoadSceneManager = true;
    vars.Helper.StartFileLogger("ViewfinderASL.log");

    settings.Add("split_exit", true, "Split on level end");
    settings.Add("1:1.1", true, "Level 1", "split_exit");
    settings.Add("1:1.2", true, "Level 2", "split_exit");
    settings.Add("1:1.3", true, "Level 3", "split_exit");
    settings.Add("1:2.1", true, "Level 4", "split_exit");
    settings.Add("1:2.3", true, "Level 5", "split_exit");
    settings.Add("1:2.4", true, "Level 6", "split_exit");
    settings.Add("3:2.1", true, "Level 7", "split_exit");

    vars.splitsDone = new HashSet<string>();
}

onStart {
    vars.splitsDone.Clear();
    vars.Log("--Run Start--");
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono => {
        // AdditiveSceneManager.instance.__state
        vars.Helper["loadState"] =
            mono["ViewfinderAssembly", "AdditiveSceneManager"]
            .Make<int>("instance", 0x30);

        // DemoEndScreenController._instance.endSlateRoot.gameObject.activeSelf
        vars.Helper["demoComplete"] =
            mono["ViewfinderAssembly", "DemoEndScreenController", 1]
            .Make<bool>("_instance", 0x20, 0x30, 0x39);

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

        return true;
    });
}

update {
    int _sceneIndex = vars.Helper.Scenes.Active.Index;
    current.sceneIndex = _sceneIndex == 0 ? old.sceneIndex : _sceneIndex;
}

start {
    return current.sceneIndex == 11 && current.loadState == 0 && old.loadState == 4;
}

split {
    if (current.demoComplete && !old.demoComplete) {
        vars.Log("Split point: Demo Complete");
        return true;
    }

    if (current.Level != old.Level) {
        vars.Log("Split Point: " + old.Level);
        vars.Log("- current.Level: " + current.Level);
        vars.Log("- old.Level: " + old.Level);
        vars.Log("- in splitsDone? " + vars.splitsDone.Contains(current.Level));
        vars.Log("- setting enabled? " + settings[old.Level]);
        if (settings[old.Level] && vars.splitsDone.Add(old.Level)) {
            vars.Log("- Split point enabled and not yet triggered, firing.");
            return true;
        } else {
            vars.Log("- Split point disabled or already triggered.");
        }
    }
}

isLoading {
    if (current.transitionState == 2) {
        return true;
    }
    if (current.transitionState == 3) {
        return current.transitionInterpolator != 1f &&
            current.transitionInterpolator == old.transitionInterpolator;
    }
}

onReset
{
    vars.Log("--Run Reset--");
}