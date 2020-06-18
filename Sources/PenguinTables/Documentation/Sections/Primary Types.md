Penguin organizes data into `PTable`s. Data is stored in columnar format inside `PTypedColumn`s,
however to make it easier to work with, `PTable`'s are composed of multiple `PColumn`s, which
hold within them a `PTypedColumn`.

Penguin methods only throw errors of type `PError`, which makes them easy to catch and handle.
