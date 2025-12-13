
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

describe("Debug Cancel Market", () => {
    it("should print result of cancel-market", () => {
        const currentBlock = simnet.blockHeight;
        const lockDate = currentBlock + 100;
        const resolutionDate = currentBlock + 200;

        // Create market
        const createRes = simnet.callPublicFn(
            "oracle-market",
            "create-market",
            [
                Cl.stringAscii("Debug Market"),
                Cl.stringUtf8("Description"),
                Cl.stringAscii("Test"),
                Cl.list([Cl.stringUtf8("A"), Cl.stringUtf8("B")]),
                Cl.uint(resolutionDate),
                Cl.uint(lockDate)
            ],
            deployer
        );
        console.log("Create Result:", JSON.stringify(createRes, null, 2));

        // Cancel as depoyer
        const cancelRes = simnet.callPublicFn(
            "oracle-market",
            "cancel-market",
            [Cl.uint(0)],
            deployer
        );
        console.log("Cancel Result (Deployer):", JSON.stringify(cancelRes, null, 2));

        expect(cancelRes.result).toBeOk(Cl.bool(true));
    });
});
