import db from "./index"
import readline from "readline"
import fs from "fs"
import path from "path"
import { v4 as uuidv4 } from "uuid"
import { SecurePassword } from "@blitzjs/auth"

/*
 * This seed function is executed when you run `blitz db seed`.
 *
 * Probably you want to use a library like https://chancejs.com
 * to easily generate realistic data.
 */

function splitStringByNotQuotedSemicolon(input: string): string[] {
  const result: any = []

  let currentSplitIndex = 0
  let isInString = false
  for (let i = 0; i < input.length; i++) {
    if (input[i] === "'") {
      // toggle isInString
      isInString = !isInString
    }
    if (input[i] === ";" && !isInString) {
      result.push(input.substring(currentSplitIndex, i + 1))
      currentSplitIndex = i + 2
    }
  }

  return result
}

const seed = async () => {
  const rawSql = await fs.promises.readFile(path.join(__dirname, "world.sql"), {
    encoding: "utf-8",
  })
  const sqlReducedToStatements = rawSql
    .split("\n")
    .filter((line) => !line.startsWith("--")) // remove comments-only lines
    .join("\n")
    .replace(/\r\n|\n|\r/g, " ") // remove newlines
    .replace(/\s+/g, " ") // excess white space
  const sqlStatements = splitStringByNotQuotedSemicolon(sqlReducedToStatements)

  for (const sql of sqlStatements) {
    console.log(sql)
    await db.$executeRawUnsafe(sql)
  }
  const input = fs.createReadStream("./db/disposable_emails.conf")
  const rl = readline.createInterface({ input })
  let dataArray: any = []
  // PROCESS LINES
  rl.on("line", async (line) => {
    //console.log(`Adding ${line}`)
    dataArray.push({ domainName: line })
  })

  await db.emailDomainBlocklist.createMany({ data: dataArray })

  const hashedPassword = await SecurePassword.hash(process.env["ADMIN_PASSWORD"])
  await db.user.create({
    data: {
      email: "etienne@cimons.com",
      hashedPassword,
      profile: {
        create: {
          fullName: "Etienne Cimon",
          mobilePhoneNumber: "+1 (418) 261-4923",
        },
      },
      role: "SUPERADMIN",
    },
  })
  // for (let i = 0; i < 5; i++) {
  //   await db.project.create({ data: { name: "Project " + i } })
  // }
}

export default seed
