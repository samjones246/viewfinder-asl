#![no_std]
extern crate alloc;

#[global_allocator]
static ALLOC: dlmalloc::GlobalDlmalloc = dlmalloc::GlobalDlmalloc;

use asr::{Address, Process, future::{IntoOption, next_tick}, settings::Gui, timer, watcher::Pair};
use asr::signature::Signature;
use bytemuck::Pod;
use alloc::vec::Vec;
use alloc::format;

static AUTOSPLITTER_DATA_SIG: Signature<19> =
    Signature::new("48 8B 05 ?? ?? ?? ?? 48 8B 88 B8 00 00 00 F2 0F 11 41 18");

static HUBS: [i32; 6] = [57, 58, 59, 60, 61, 62];

asr::async_main!(stable);
asr::panic_handler!();

struct Watcher<'a, T> {
    watcher: asr::watcher::Watcher<T>,
    address: Address,
    offsets: &'a[u64],
}

impl<'a, T : Pod> Watcher<'a, T> {
    fn new(address: Address, offsets: &'a [u64]) -> Self {
        Self {
            watcher: asr::watcher::Watcher::new(),
            address,
            offsets,
        }
    }

    fn update(&mut self, process: &Process) -> Option<&Pair<T>> {
        self.watcher.update(
            process.read_pointer_path(
                self.address, 
                asr::PointerSize::Bit64,
                self.offsets
            ).into_option()
        )
    }
}

#[derive(Gui)]
struct Settings {
    /// Split on sub-level end
    #[default = false]
    split_level: bool,

    /// Split on level end
    #[default = true]
    split_hub_enter: bool,

    /// Split on level start
    #[default = false]
    split_hub_exit: bool,

    /// Split on moving to next hub
    #[default = false]
    split_hub_transition: bool,

    /// Individual Level Mode
    #[default = false]
    il_mode: bool,
}

async fn main() {
    let mut settings = Settings::register();

    loop {
        let process = Process::wait_attach("Viewfinder.exe").await;

        // Sigscan for AutoSplitterData
        let module_range = process.get_module_range("GameAssembly.dll").unwrap();
        let addr: Address = AUTOSPLITTER_DATA_SIG.scan_process_range(&process, module_range).unwrap() + 0x3;
        let addr: Address = addr + 0x4 + process.read::<u32>(addr).unwrap();
        asr::print_message(&format!("AutoSplitterData addr: {:x}", addr.value()));

        // Set up memory watchers
        let mut w_is_loading: Watcher<u8> = Watcher::new(addr, &[0x00, 0xB8, 0x20]);
        let mut w_is_riding_train: Watcher<u8> = Watcher::new(addr, &[0x00, 0xB8, 0x22]);
        let mut w_level_id: Watcher<i32> = Watcher::new(addr, &[0x00, 0xB8, 0x24]);
        let mut w_is_running: Watcher<i32> = Watcher::new(addr, &[0x00, 0xB8, 0x2C]);

        // Other state
        let mut splits_done: Vec<(i32, i32)> = Vec::new();
        let mut prev_level: i32 = -1;

        process
            .until_closes(async {
                loop {
                    // Update
                    settings.update();
                    let is_loading = w_is_loading.update(&process).unwrap();
                    timer::set_variable("is_loading", &format!("{}", is_loading.current == 1));

                    let is_riding_train = w_is_riding_train.update(&process).unwrap();
                    timer::set_variable("is_riding_train", &format!("{}", is_riding_train.current == 1));

                    let level_id = w_level_id.update(&process).unwrap();
                    timer::set_variable("level_id", &format!("{}", level_id.current));

                    let is_running = w_is_running.update(&process).unwrap();
                    timer::set_variable("is_running", &format!("{}", is_running.current == 1));

                    if level_id.changed() {
                        prev_level = level_id.old;
                    }

                    // Start
                    if is_loading.changed_to(&0) {
                        let should_start = if settings.il_mode {
                            HUBS.contains(&prev_level) && !HUBS.contains(&level_id.current)
                        } else {
                            level_id.current == 31
                        };
                        if should_start {
                            splits_done.clear();
                            timer::start();
                        }
                    }

                    // Split
                    if is_running.changed_from_to(&1, &2) {
                        timer::split();
                    }
                    if level_id.changed() && !splits_done.contains(&(level_id.old, level_id.current)) {
                        splits_done.push((level_id.old, level_id.current));
                        let hub_enter = HUBS.contains(&level_id.current);
                        let hub_exit = HUBS.contains(&level_id.old);
                        if hub_enter && hub_exit {
                            // Do nothing
                        } else if settings.split_hub_enter && hub_enter && level_id.old != 81 {
                            timer::split();
                        } else if settings.split_hub_exit && hub_exit {
                            timer::split();
                        } else if settings.split_level && !hub_exit {
                            timer::split();
                        }
                    }
                    if settings.split_hub_transition
                        && is_riding_train.changed_to(&1)
                        && !splits_done.contains(&(level_id.current, 255)) 
                    {
                        splits_done.push((level_id.current, 255));
                        timer::split();
                    }

                    // Loading
                    if is_loading.changed_to(&1) {
                        timer::pause_game_time();
                    }
                    if is_loading.changed_to(&0) {
                        timer::resume_game_time();
                    }

                    next_tick().await;
                }
            })
            .await;
    }
}
