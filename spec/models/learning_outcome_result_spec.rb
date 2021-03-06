#
# Copyright (C) 2011-2012 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe LearningOutcomeResult do

  let_once :learning_outcome_result do
    create_and_associate_lor(quiz_model)
  end

  def create_and_associate_lor(association_object)
    assignment_model
    outcome = @course.created_learning_outcomes.create!(title: 'outcome')

    LearningOutcomeResult.new(
      alignment: ContentTag.create!({
        title: 'content',
        context: @course,
        learning_outcome: outcome})
      ).tap do |lor|
        lor.association_object = association_object
        lor.context = @course
        lor.associated_asset = association_object
        lor.save!
      end
  end

  describe '.association_type' do
    it 'returns the correct representation of a quiz' do
      expect(learning_outcome_result.association_type).to eq 'Quizzes::Quiz'

      learning_outcome_result.association_type = 'Quiz'
      learning_outcome_result.send(:save_without_callbacks)

      expect(LearningOutcomeResult.first.association_type).to eq 'Quizzes::Quiz'
    end

    it 'returns the association type attribute if not a quiz' do
      learning_outcome_result.association_object = assignment_model
      learning_outcome_result.send(:save_without_callbacks)
      expect(learning_outcome_result.association_type).to eq 'Assignment'
    end
  end

  describe '.artifact_type' do
    it 'returns the correct representation of a quiz submission' do
      sub = learning_outcome_result.association_object.quiz_submissions.create!

      learning_outcome_result.artifact = sub
      learning_outcome_result.save
      expect(learning_outcome_result.artifact_type).to eq 'Quizzes::QuizSubmission'

      LearningOutcomeResult.where(id: learning_outcome_result).update_all(association_type: 'QuizSubmission')

      expect(LearningOutcomeResult.find(learning_outcome_result.id).artifact_type).to eq 'Quizzes::QuizSubmission'
    end
  end

  describe '.associated_asset_type' do
    it 'returns the correct representation of a quiz' do
      expect(learning_outcome_result.associated_asset_type).to eq 'Quizzes::Quiz'

      learning_outcome_result.associated_asset_type = 'Quiz'
      learning_outcome_result.send(:save_without_callbacks)

      expect(LearningOutcomeResult.first.associated_asset_type).to eq 'Quizzes::Quiz'
    end

    it 'returns the associated asset type attribute if not a quiz' do
      learning_outcome_result.associated_asset = assignment_model
      learning_outcome_result.send(:save_without_callbacks)

      expect(learning_outcome_result.associated_asset_type).to eq 'Assignment'
    end
  end

  describe '#submitted_or_assessed_at' do
    before(:once) do
      @submitted_at = 1.month.ago
      @assessed_at = 2.weeks.ago
    end

    it 'returns #submitted_at when present' do
      learning_outcome_result.update_attribute(:submitted_at, @submitted_at)
      expect(learning_outcome_result.submitted_or_assessed_at).to eq(@submitted_at)
    end

    it 'returns #assessed_at when #submitted_at is not present' do
      learning_outcome_result.assign_attributes({
        assessed_at: @assessed_at,
        submitted_at: nil
      })
      expect(learning_outcome_result.submitted_or_assessed_at).to eq(@assessed_at)
    end

  end

  describe "active scope" do
    it "doesn't return deleted outcomes" do
      expect(LearningOutcomeResult.active.count).to eq(1), "precondition"
      learning_outcome_result.alignment.workflow_state = 'deleted'
      learning_outcome_result.alignment.save!
      expect(LearningOutcomeResult.active.count).to eq 0
    end
  end

  describe "#calculate percent!" do
    it "properly calculates percent" do
      learning_outcome_result.update_attribute(:score, 6)
      learning_outcome_result.update_attribute(:possible, 10)
      learning_outcome_result.calculate_percent!

      expect(learning_outcome_result.percent).to eq 0.60
    end

    it "returns accurate results" do
      points_possible = 5.5
      learning_outcome_result.learning_outcome.stubs({
        points_possible: points_possible, mastery_points: 3.5
      })
      learning_outcome_result.alignment.stubs(mastery_score: 0.6)
      learning_outcome_result.update_attribute(:score, 6)
      learning_outcome_result.update_attribute(:possible, 10)
      learning_outcome_result.calculate_percent!
      mastery_score = (learning_outcome_result.percent * points_possible).round(2)
      expect(mastery_score).to eq 3.5
    end

    it "properly scales score to parent outcome's mastery level" do
      learning_outcome_result.learning_outcome.stubs({
        points_possible: 5.0, mastery_points: 3.0
      })
      learning_outcome_result.alignment.stubs(mastery_score: 0.7)
      learning_outcome_result.update_attribute(:score, 6)
      learning_outcome_result.update_attribute(:possible, 10)
      learning_outcome_result.calculate_percent!

      expect(learning_outcome_result.percent).to eq 0.5143
    end

    it "does not fail if parent outcome has integers instead of floats" do
      learning_outcome_result.learning_outcome.stubs({
        points_possible: 5, mastery_points: 3
      })
      learning_outcome_result.alignment.stubs(mastery_score: 0.7)
      learning_outcome_result.update_attribute(:score, 6)
      learning_outcome_result.update_attribute(:possible, 10)
      learning_outcome_result.calculate_percent!

      expect(learning_outcome_result.percent).to eq 0.5143
    end
  end

  describe '#assignment' do
    it 'returns the Assignment if association object is Assignment' do
      assignment = assignment_model
      lor = create_and_associate_lor(assignment)

      expect(lor.assignment).to eq(assignment)
    end

    it 'returns the Assignment from the artifact if one doesnt explicitly exist' do
      lor = create_and_associate_lor(nil)
      lor.artifact = rubric_assessment_model(user: @user, context: @course)

      expect(lor.assignment).to eq(lor.artifact.assignment)
    end

    it 'returns nil if no explicit assignment or artifact exists' do
      lor = create_and_associate_lor(nil)

      expect(lor.assignment).to eq(nil)
    end
  end

  describe '#save_to_version' do
    it 'updates the attempt version with the current model state' do
      learning_outcome_result.attempt = 1
      learning_outcome_result.save!
      attempt1_version = learning_outcome_result.versions.current

      attributes = {
        score: 20,
        mastery: true,
        possible: 20,
        attempt: 2,
        title: "Foobar"
      }

      attributes.each do |method_name, value|
        learning_outcome_result.send("#{method_name}=".to_sym, value)
      end
      learning_outcome_result.save!

      updated_version = learning_outcome_result.versions.where(id: attempt1_version.id).first
      version_model = updated_version.model

      expect(version_model).not_to have_attributes(attributes)

      learning_outcome_result.save_to_version(1)
      updated_version = learning_outcome_result.versions.where(id: attempt1_version.id).first
      version_model = updated_version.model

      expect(version_model).to have_attributes(attributes)
    end
  end
end
