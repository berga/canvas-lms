import React from 'react'
import classNames from 'classnames'
import I18n from 'i18n!choose_mastery_path'
import Assignment from './assignment'
import SelectButton from './select-button'
import assignmentShape from '../shapes/assignment-shape'
  const { func, number, arrayOf } = React.PropTypes

export default class PathOption extends React.Component {
    static propTypes = {
      assignments: arrayOf(assignmentShape).isRequired,
      optionIndex: number.isRequired,
      setId: number.isRequired,
      selectedOption: number,
      selectOption: func.isRequired,
    }

    constructor () {
      super()
      this.selectOption = this.selectOption.bind(this)
    }

    selectOption () {
      this.props.selectOption(this.props.setId)
    }

    render () {
      const { selectedOption, setId, optionIndex } = this.props
      const disabled = selectedOption !== null && selectedOption !== undefined && selectedOption !== setId
      const selected = selectedOption === setId

      const optionClasses = classNames({
        'item-group-container': true,
        'cmp-option': true,
        'cmp-option__selected': selected,
        'cmp-option__disabled': disabled,
      })

      return (
        <div className={optionClasses}>
          <div className='item-group-condensed context_module'>
            <div className='ig-header'>
              <span className='name'>
                {I18n.t('Option %{index}', { index: optionIndex + 1 })}
              </span>
              <SelectButton isDisabled={disabled} isSelected={selected} onSelect={this.selectOption} />
            </div>
            <ul className='ig-list'>
              {this.props.assignments.map((assg, i) => (
                <Assignment
                  key={i}
                  assignment={assg}
                  isSelected={selected}
                />
              ))}
            </ul>
          </div>
        </div>
      )
    }
  }
