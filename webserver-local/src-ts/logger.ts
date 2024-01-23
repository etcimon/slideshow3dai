import { createLogger, format, transports } from 'winston'

const { combine, timestamp, prettyPrint, colorize, errors } = format

const logger = createLogger({
    format: combine(
        errors({ stack: true }), // <-- use errors format
        colorize(),
        timestamp(),
        prettyPrint()
    ),
    transports: [new transports.Console()],
})

export default logger
