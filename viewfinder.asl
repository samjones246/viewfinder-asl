state("Viewfinder_Demo") {
    bool isLoading: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x20;
    bool isTransition: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x21;
    bool isMainMenu: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x22;
    int levelID: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x24;
    int isRunning: "GameAssembly.dll", 0x3CA88C8, 0xB8, 0x28;
}

startup {
    settings.Add("split_exit", true, "Split on level end");
    settings.Add("12", true, "Level 1", "split_exit");
    settings.Add("8", true, "Level 2", "split_exit");
    settings.Add("13", true, "Level 3", "split_exit");
    settings.Add("9", true, "Level 4", "split_exit");
    settings.Add("6", true, "Level 5", "split_exit");
    settings.Add("10", true, "Level 6", "split_exit");
    settings.Add("11", true, "Level 7", "split_exit");

    vars.splitsDone = new HashSet<int>();
}

onStart {
    vars.splitsDone.Clear();
}

start {
    return !current.isLoading && old.isLoading && current.levelID == 12;
}

reset
{
    return current.isMainMenu && !old.isMainMenu;
}

split {
    if (current.isRunning == 2 && old.isRunning == 1) {
        return true;
    }

    if (current.levelID != old.levelID) {
        return settings[old.levelID.ToString()] && vars.splitsDone.Add(old.levelID);
    }
}

isLoading {
    return current.isTransition && current.isLoading;
}