import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/director/director_budget_service.dart';

void main() {
  group('DirectorBudgetService', () {
    late AppDatabase db;
    late DirectorBudgetService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = DirectorBudgetService(db);
    });

    tearDown(() async {
      await db.close();
    });

    DirectorBudgetPlan buildPlan() {
      return DirectorBudgetPlan(
        academicYear: 2026,
        term: 3,
        monthsInTerm: 4,
        canteenExpenseRows: [
          BudgetExpenseRow(
            itemName: 'Rice',
            unitPrice: 14,
            monthlyQuantities: [2, 3, 1, 4],
          ),
        ],
        canteenFeeRows: [
          CanteenFeeBudgetRow(
            classId: 7,
            classLabel: 'JHS 1',
            studentCount: 32,
            amountPerChild: 8,
            daysPerWeek: 5,
            weeksPerMonth: 4,
          ),
        ],
        schoolFeeRows: [
          SchoolFeeBudgetRow(
            classId: 7,
            classLabel: 'JHS 1',
            studentCount: 32,
            amount: 150,
          ),
        ],
        monthlySalaryBudget: 4000,
        monthlyTaxBudget: 450,
        monthlySsnitBudget: 300,
      );
    }

    test('saveBudgetDraft persists plan without creating a snapshot', () async {
      final plan = buildPlan();

      await service.saveBudgetDraft(plan);

      final reloadedService = DirectorBudgetService(db);
      final savedPlan = await reloadedService.getBudgetPlan(academicYear: 2026, term: 3);
      final snapshots = await reloadedService.getBudgetSnapshots();

      expect(savedPlan.academicYear, 2026);
      expect(savedPlan.term, 3);
      expect(savedPlan.monthsInTerm, 4);
      expect(savedPlan.canteenExpenseRows.single.itemName, 'Rice');
      expect(savedPlan.canteenExpenseRows.single.unitPrice, 14);
      expect(savedPlan.canteenFeeRows.single.termTotal(savedPlan.monthsInTerm), 20480);
      expect(savedPlan.schoolFeeRows.single.total, 4800);
      expect(savedPlan.monthlyPayrollTotal, 4750);
      expect(snapshots, isEmpty);
    });

    test('saveBudgetPlan keeps draft data and writes a revision snapshot', () async {
      final plan = buildPlan();

      await service.saveBudgetPlan(
        plan,
        replaceLatestSnapshot: false,
        snapshotNote: 'Initial approved revision',
      );

      final savedPlan = await service.getBudgetPlan(academicYear: 2026, term: 3);
      final snapshots = await service.getBudgetSnapshots();

      expect(savedPlan.totalExpensesPerTerm, plan.totalExpensesPerTerm);
      expect(savedPlan.totalSchoolFees, plan.totalSchoolFees);
      expect(snapshots, hasLength(1));
      expect(snapshots.single.note, 'Initial approved revision');
      expect(snapshots.single.plan.term, 3);
      expect(snapshots.single.plan.monthlySalaryBudget, 4000);
    });
  });
}