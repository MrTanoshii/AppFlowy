use crate::{
    module::{Event, Module},
    rt::Runtime,
    stream::CommandSenderRunner,
};
use futures_core::{ready, task::Context};
use std::{cell::RefCell, collections::HashMap, fmt::Debug, future::Future, io, rc::Rc, sync::Arc};
use tokio::{
    macros::support::{Pin, Poll},
    sync::{
        mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender},
        oneshot,
    },
};

thread_local!(
    static CURRENT: RefCell<Option<Arc<FlowySystem>>> = RefCell::new(None);
);

#[derive(Debug)]
pub enum SystemCommand {
    Exit(i8),
}

pub type ModuleMap = Rc<HashMap<Event, Rc<Module>>>;
pub struct FlowySystem {
    sys_cmd_tx: UnboundedSender<SystemCommand>,
}

impl FlowySystem {
    pub fn construct<F, S, T>(module_factory: F, sender_factory: S) -> SystemRunner
    where
        // E: Into<Event<E>> + Eq + Hash + Debug + Clone + 'static,
        F: FnOnce() -> Vec<Module>,
        S: FnOnce(ModuleMap) -> CommandSenderRunner<T>,
        T: 'static,
    {
        let runtime = Runtime::new().unwrap();
        let (sys_cmd_tx, sys_cmd_rx) = unbounded_channel::<SystemCommand>();
        let (stop_tx, stop_rx) = oneshot::channel();

        runtime.spawn(SystemController {
            stop_tx: Some(stop_tx),
            sys_cmd_rx,
        });

        let factory = module_factory();
        let mut module_map = HashMap::new();
        factory.into_iter().for_each(|m| {
            let events = m.events();
            let rc_module = Rc::new(m);
            events.into_iter().for_each(|e| {
                module_map.insert(e, rc_module.clone());
            });
        });

        let system = Self { sys_cmd_tx };
        let sender_runner = sender_factory(Rc::new(module_map));
        runtime.spawn(sender_runner);

        FlowySystem::set_current(system);
        let runner = SystemRunner { rt: runtime, stop_rx };
        runner
    }

    pub fn stop(&self) {
        match self.sys_cmd_tx.send(SystemCommand::Exit(0)) {
            Ok(_) => {},
            Err(e) => {
                log::error!("Stop system error: {}", e);
            },
        }
    }

    #[doc(hidden)]
    pub fn set_current(sys: FlowySystem) {
        CURRENT.with(|cell| {
            *cell.borrow_mut() = Some(Arc::new(sys));
        })
    }

    pub fn current() -> Arc<FlowySystem> {
        CURRENT.with(|cell| match *cell.borrow() {
            Some(ref sys) => sys.clone(),
            None => panic!("System is not running"),
        })
    }
}

struct SystemController {
    stop_tx: Option<oneshot::Sender<i8>>,
    sys_cmd_rx: UnboundedReceiver<SystemCommand>,
}

impl Future for SystemController {
    type Output = ();
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        loop {
            match ready!(Pin::new(&mut self.sys_cmd_rx).poll_recv(cx)) {
                None => return Poll::Ready(()),
                Some(cmd) => match cmd {
                    SystemCommand::Exit(code) => {
                        if let Some(tx) = self.stop_tx.take() {
                            let _ = tx.send(code);
                        }
                    },
                },
            }
        }
    }
}

pub struct SystemRunner {
    rt: Runtime,
    stop_rx: oneshot::Receiver<i8>,
}

impl SystemRunner {
    pub fn run(self) -> io::Result<()> {
        let SystemRunner { rt, stop_rx } = self;
        match rt.block_on(stop_rx) {
            Ok(code) => {
                if code != 0 {
                    Err(io::Error::new(
                        io::ErrorKind::Other,
                        format!("Non-zero exit code: {}", code),
                    ))
                } else {
                    Ok(())
                }
            },
            Err(e) => Err(io::Error::new(io::ErrorKind::Other, e)),
        }
    }

    pub fn spawn<F: Future<Output = ()> + 'static>(self, future: F) -> Self {
        self.rt.spawn(future);
        self
    }
}