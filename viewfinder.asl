state("Viewfinder_Demo"){}

startup
{
    vars.Log = (Action<object>)((output) => print("[Viewfinder ASL] " + output));
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "Viewfinder Demo";
    vars.Helper.LoadSceneManager = true;

    // vars.Levels = new int[] { 11, 7, 12, 8, 5, 9, 10, 6 }

    settings.Add("split_exit", true, "Split on level end");
    settings.Add("split_exit_11", true, "Level 1", "split_exit");
    settings.Add("split_exit_7", true, "Level 2", "split_exit");
    settings.Add("split_exit_12", true, "Level 3", "split_exit");
    settings.Add("split_exit_8", true, "Level 4", "split_exit");
    settings.Add("split_exit_5", true, "Level 5", "split_exit");
    settings.Add("split_exit_9", true, "Level 6", "split_exit");
    settings.Add("split_exit_10", true, "Level 7", "split_exit");
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono => {
        // AdditiveSceneManager.instance.__state
        vars.Helper["loadState"] = mono["ViewfinderAssembly", "AdditiveSceneManager"]
            .Make<int>("instance", 0x30);

        // DemoEndScreenController._instance.endSlateRoot.gameObject.activeSelf
        vars.Helper["demoComplete"] = mono["ViewfinderAssembly", "DemoEndScreenController", 1]
            .Make<bool>("_instance", 0x20, 0x30, 0x39);

        return true;
    });
}

start
{
    return current.sceneIndex == 11 && current.loadState == 0 && old.loadState == 4;
}

split
{
    if (current.demoComplete && !old.demoComplete) {
        return true;
    }
    if (current.sceneIndex != old.sceneIndex) {
        return settings["split_exit_"+old.sceneIndex];
    }
}

update
{
    int _sceneIndex = vars.Helper.Scenes.Active.Index;
    current.sceneIndex = _sceneIndex == 0 ? old.sceneIndex : _sceneIndex;
    current.loadState = vars.Helper["loadState"].Current;
    current.demoComplete = vars.Helper["demoComplete"].Current;
}

isLoading
{
    return current.loadState != 0;
}